export type AmplifyDependentResourcesAttributes = {
  "api": {
    "shiftlinkmain": {
      "GraphQLAPIEndpointOutput": "string",
      "GraphQLAPIIdOutput": "string"
    }
  },
  "auth": {
    "shiftlinkmain32f72376": {
      "AppClientID": "string",
      "AppClientIDWeb": "string",
      "IdentityPoolId": "string",
      "IdentityPoolName": "string",
      "UserPoolArn": "string",
      "UserPoolId": "string",
      "UserPoolName": "string"
    }
  },
  "function": {
    "overtimeNotifier": {
      "Arn": "string",
      "LambdaExecutionRoleArn": "string",
      "Name": "string"
    },
    "rotationEscalationWatcher": {
      "Arn": "string",
      "CloudWatchEventRule": "string",
      "LambdaExecutionRole": "string",
      "LambdaExecutionRoleArn": "string",
      "Name": "string",
      "Region": "string"
    }
  }
}