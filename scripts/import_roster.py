#!/usr/bin/env python3
"""
Bulk-import officers from a CSV into Cognito and the AppSync roster assignments.

Usage:
    python3 scripts/import_roster.py path/to/roster.csv --org-id SBPD [--dry-run]

Prereqs:
    pip install boto3 requests
    The script will auto-read `amplify/backend/amplify-meta.json` for pool/app IDs.
    Export DW_USER_POOL_ID, DW_APP_CLIENT_ID, or DW_APPSYNC_URL to override.
"""

import argparse
import csv
import json
import os
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Dict, List, Optional

import boto3
import requests
from botocore.auth import SigV4Auth
from botocore.awsrequest import AWSRequest

REQUIRED_COLUMNS = ["BadgeOrComputerNumber", "Email", "GroupSelection"]
OPTIONAL_COLUMNS = ["FirstName", "LastName", "Rank", "PhoneNumber", "Assignment"]
GROUP_LOOKUP = {
    "non-supervisor": "Non-Supervisor",
    "nonsupervisor": "Non-Supervisor",
    "supervisor": "Supervisor",
    "admin": "Admin",
}

AMPLIFY_META_PATH = Path(__file__).resolve().parents[1] / "amplify" / "backend" / "amplify-meta.json"


def _first_value(mapping: Dict[str, dict]) -> dict:
    for value in mapping.values():
        if isinstance(value, dict):
            return value
    return {}


def _load_amplify_defaults() -> Dict[str, Optional[str]]:
    try:
        with AMPLIFY_META_PATH.open("r", encoding="utf-8") as fh:
            meta = json.load(fh)
    except FileNotFoundError:
        return {}
    except json.JSONDecodeError:
        return {}

    defaults: Dict[str, Optional[str]] = {}
    auth_output = _first_value(meta.get("auth", {})).get("output", {})
    api_output = _first_value(meta.get("api", {})).get("output", {})

    defaults["userPoolId"] = auth_output.get("UserPoolId")
    defaults["appClientId"] = auth_output.get("AppClientID") or auth_output.get("AppClientIDWeb")
    defaults["appsyncUrl"] = api_output.get("GraphQLAPIEndpointOutput")
    return defaults


_AMPLIFY_DEFAULTS = _load_amplify_defaults()

FALLBACK_USER_POOL_ID = "us-east-1_59rtx0vcO"
FALLBACK_APP_CLIENT_ID = "2efdllcd7rtqmu07djuiii34i"
FALLBACK_APPSYNC_URL = "https://qxcmvpayzbadhbrj4ead6egixy.appsync-api.us-east-1.amazonaws.com/graphql"

USER_POOL_ID = os.environ.get("DW_USER_POOL_ID") or _AMPLIFY_DEFAULTS.get("userPoolId") or FALLBACK_USER_POOL_ID
APP_CLIENT_ID = os.environ.get("DW_APP_CLIENT_ID") or _AMPLIFY_DEFAULTS.get("appClientId") or FALLBACK_APP_CLIENT_ID
APPSYNC_URL = os.environ.get("DW_APPSYNC_URL") or _AMPLIFY_DEFAULTS.get("appsyncUrl") or FALLBACK_APPSYNC_URL
IAM_REGION = os.environ.get("DW_REGION", "us-east-1")
TEMP_PASSWORD = os.environ.get("DW_TEMP_PASSWORD", "DutyWire#123")
AWS_PROFILE = os.environ.get("AWS_PROFILE")


@dataclass
class OfficerRow:
    badge_number: str
    email: str
    group: str
    first_name: Optional[str] = None
    last_name: Optional[str] = None
    rank: Optional[str] = None
    phone: Optional[str] = None
    assignment: Optional[str] = None

    @property
    def full_name(self) -> Optional[str]:
        if self.first_name and self.last_name:
            return f"{self.first_name} {self.last_name}"
        if self.first_name:
            return self.first_name
        if self.last_name:
            return self.last_name
        return None


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Import roster CSV")
    parser.add_argument("csv_path", type=Path)
    parser.add_argument("--org-id", required=True, help="Org ID (matches custom:orgID)")
    parser.add_argument("--dry-run", action="store_true", help="Only validate; don't call AWS")
    return parser.parse_args()


def load_csv(path: Path) -> List[OfficerRow]:
    with path.open("r", newline="", encoding="utf-8-sig") as fh:
        reader = csv.DictReader(fh)
        missing = [col for col in REQUIRED_COLUMNS if col not in reader.fieldnames]
        if missing:
            raise ValueError(f"Missing required columns: {missing}")

        rows: List[OfficerRow] = []
        for line_num, record in enumerate(reader, start=2):
            badge = (record.get("BadgeOrComputerNumber") or "").strip()
            email = (record.get("Email") or "").strip()
            group_raw = (record.get("GroupSelection") or "").strip()
            group = GROUP_LOOKUP.get(group_raw.lower())
            if not badge:
                raise ValueError(f"Row {line_num}: BadgeOrComputerNumber is required")
            if not email:
                raise ValueError(f"Row {line_num}: Email is required")
            if not group:
                allowed = ", ".join(sorted(GROUP_LOOKUP.values()))
                raise ValueError(
                    f"Row {line_num}: GroupSelection must be one of [{allowed}], got '{group_raw}'"
                )

            rows.append(
                OfficerRow(
                    badge_number=badge,
                    email=email,
                    group=group,
                    first_name=(record.get("FirstName") or "").strip() or None,
                    last_name=(record.get("LastName") or "").strip() or None,
                    rank=(record.get("Rank") or "").strip() or None,
                    phone=(record.get("PhoneNumber") or "").strip() or None,
                    assignment=(record.get("Assignment") or "").strip() or None,
                )
            )
    return rows


aws_session = boto3.Session(profile_name=AWS_PROFILE) if AWS_PROFILE else boto3.Session()
cognito = aws_session.client("cognito-idp", region_name=IAM_REGION)
http_session = requests.Session()

UPDATE_ASSIGNMENT_MUTATION = """
mutation UpdateAssignment($input: UpdateOfficerAssignmentInput!) {
  updateOfficerAssignment(input: $input) {
    id
  }
}
"""

CREATE_ASSIGNMENT_MUTATION = """
mutation CreateAssignment($input: CreateOfficerAssignmentInput!) {
  createOfficerAssignment(input: $input) {
    id
  }
}
"""


def call_appsync(query: str, variables: dict) -> dict:
    payload = {"query": query, "variables": variables}
    aws_request = AWSRequest(
        method="POST",
        url=APPSYNC_URL,
        data=json.dumps(payload),
        headers={"Content-Type": "application/json"},
    )
    creds = aws_session.get_credentials().get_frozen_credentials()
    SigV4Auth(creds, "appsync", IAM_REGION).add_auth(aws_request)
    prepared = requests.Request(
        method=aws_request.method,
        url=aws_request.url,
        headers=dict(aws_request.headers.items()),
        data=aws_request.body,
    ).prepare()
    response = http_session.send(prepared)
    response.raise_for_status()
    data = response.json()
    if "errors" in data:
        raise RuntimeError(data["errors"])
    return data["data"]


def ensure_cognito_user(officer: OfficerRow, org_id: str) -> str:
    username = officer.email.strip()
    preferred_username = officer.full_name or officer.badge_number
    attributes = [
        {"Name": "email", "Value": username},
        {"Name": "email_verified", "Value": "true"},
        {"Name": "preferred_username", "Value": preferred_username},
        {"Name": "custom:orgID", "Value": org_id},
    ]
    if officer.full_name:
        attributes.append({"Name": "name", "Value": officer.full_name})
    if officer.first_name:
        attributes.append({"Name": "given_name", "Value": officer.first_name})
    if officer.last_name:
        attributes.append({"Name": "family_name", "Value": officer.last_name})
    if officer.rank:
        attributes.append({"Name": "custom:rank", "Value": officer.rank})
    if officer.phone:
        attributes.append({"Name": "phone_number", "Value": officer.phone})

    user_record = None
    try:
        user_record = cognito.admin_get_user(UserPoolId=USER_POOL_ID, Username=username)
        cognito.admin_update_user_attributes(
            UserPoolId=USER_POOL_ID,
            Username=username,
            UserAttributes=attributes,
        )
    except cognito.exceptions.UserNotFoundException:
        cognito.admin_create_user(
            UserPoolId=USER_POOL_ID,
            Username=username,
            TemporaryPassword=TEMP_PASSWORD,
            MessageAction="SUPPRESS",
            UserAttributes=attributes,
        )
        user_record = cognito.admin_get_user(UserPoolId=USER_POOL_ID, Username=username)

    cognito.admin_add_user_to_group(
        UserPoolId=USER_POOL_ID,
        Username=username,
        GroupName=officer.group,
    )

    if not user_record:
        user_record = cognito.admin_get_user(UserPoolId=USER_POOL_ID, Username=username)

    for attribute in user_record.get("UserAttributes", []):
        if attribute.get("Name") == "sub":
            return attribute.get("Value")
    raise RuntimeError(f"Unable to determine Cognito user ID for {username}")

def build_profile_notes(officer: OfficerRow, user_id: str) -> Optional[str]:
    profile = {}
    if officer.full_name:
        profile["fullName"] = officer.full_name
    if officer.rank:
        profile["rank"] = officer.rank
    if officer.phone:
        profile["departmentPhone"] = officer.phone
    profile["userId"] = user_id
    if not profile:
        return None
    return json.dumps(profile)


def upsert_assignment(officer: OfficerRow, org_id: str, user_id: str) -> None:
    if not officer.assignment:
        return
    assignment_id = f"{org_id}-{officer.badge_number}"
    input_payload = {
        "id": assignment_id,
        "orgId": org_id,
        "badgeNumber": officer.badge_number,
        "title": officer.assignment,
        "detail": officer.rank,
        "location": None,
        "notes": build_profile_notes(officer, user_id),
    }
    try:
        call_appsync(UPDATE_ASSIGNMENT_MUTATION, {"input": input_payload})
    except RuntimeError:
        call_appsync(CREATE_ASSIGNMENT_MUTATION, {"input": input_payload})


def process_officer(officer: OfficerRow, org_id: str, dry_run: bool) -> None:
    print(f"- {officer.badge_number}: {officer.email} [{officer.group}] assignment={officer.assignment!r}")
    if dry_run:
        return
    user_id = ensure_cognito_user(officer, org_id)
    upsert_assignment(officer, org_id, user_id)


def main():
    args = parse_args()
    rows = load_csv(args.csv_path)
    print(f"Loaded {len(rows)} rows for org {args.org_id}")

    for officer in rows:
        try:
            process_officer(officer, args.org_id, args.dry_run)
        except Exception as exc:  # noqa: BLE001
            print(f"  ! Failed for {officer.badge_number}: {exc}")

    print("Import completed.")


if __name__ == "__main__":
    sys.exit(main())
