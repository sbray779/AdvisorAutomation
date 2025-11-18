{
  "$schema": "https://schema.management.azure.com/providers/Microsoft.Logic/schemas/2016-06-01/workflowdefinition.json#",
  "contentVersion": "1.0.0.0",
  "parameters": {
    "subscriptionId": {
      "type": "String",
      "defaultValue": "${subscription_id}"
    },
    "storageAccountName": {
      "type": "String",
      "defaultValue": "${storage_account_name}"
    },
    "containerName": {
      "type": "String",
      "defaultValue": "${container_name}"
    }
  },
  "triggers": {
    "DailySchedule": {
      "type": "Recurrence",
      "recurrence": {
        "frequency": "Day",
        "interval": 1,
        "timeZone": "UTC",
        "startTime": "2024-01-01T06:00:00Z"
      }
    }
  },
  "actions": {
    "Initialize_CurrentDate": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "CurrentDate",
            "type": "String",
            "value": "@{formatDateTime(utcNow(), 'yyyy-MM-dd-HHmmss')}"
          }
        ]
      },
      "runAfter": {}
    },
    "Initialize_FileName": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "FileName",
            "type": "String",
            "value": "@{concat('advisor-recommendations-', variables('CurrentDate'), '.json')}"
          }
        ]
      },
      "runAfter": {
        "Initialize_CurrentDate": ["Succeeded"]
      }
    },
    "Initialize_AllRecommendations": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "AllRecommendations",
            "type": "Array",
            "value": []
          }
        ]
      },
      "runAfter": {
        "Initialize_FileName": ["Succeeded"]
      }
    },
    "Initialize_NextLink": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "NextLink",
            "type": "String",
            "value": "https://management.azure.com/subscriptions/@{parameters('subscriptionId')}/providers/Microsoft.Advisor/recommendations?api-version=2020-01-01"
          }
        ]
      },
      "runAfter": {
        "Initialize_AllRecommendations": ["Succeeded"]
      }
    },
    "Until_No_More_Pages": {
      "type": "Until",
      "expression": "@equals(variables('NextLink'), '')",
      "limit": {
        "count": 100,
        "timeout": "PT1H"
      },
      "actions": {
        "Get_Advisor_Page": {
          "type": "Http",
          "inputs": {
            "method": "GET",
            "uri": "@variables('NextLink')",
            "authentication": {
              "type": "ManagedServiceIdentity",
              "identity": "${managed_identity_id}"
            }
          },
          "runAfter": {}
        },
        "Parse_Response": {
          "type": "ParseJson",
          "inputs": {
            "content": "@body('Get_Advisor_Page')",
            "schema": {
              "type": "object",
              "properties": {
                "value": {
                  "type": "array"
                },
                "nextLink": {
                  "type": "string"
                }
              }
            }
          },
          "runAfter": {
            "Get_Advisor_Page": ["Succeeded"]
          }
        },
        "Append_Recommendations": {
          "type": "Foreach",
          "foreach": "@body('Parse_Response')?['value']",
          "actions": {
            "Append_Single_Recommendation": {
              "type": "AppendToArrayVariable",
              "inputs": {
                "name": "AllRecommendations",
                "value": "@items('Append_Recommendations')"
              }
            }
          },
          "runAfter": {
            "Parse_Response": ["Succeeded"]
          }
        },
        "Update_NextLink": {
          "type": "SetVariable",
          "inputs": {
            "name": "NextLink",
            "value": "@{coalesce(body('Parse_Response')?['nextLink'], '')}"
          },
          "runAfter": {
            "Append_Recommendations": ["Succeeded"]
          }
        }
      },
      "runAfter": {
        "Initialize_NextLink": ["Succeeded"]
      }
    },
    "Create_JSON_Blob": {
      "type": "Http",
      "inputs": {
        "method": "PUT",
        "uri": "https://@{parameters('storageAccountName')}.blob.core.windows.net/@{parameters('containerName')}/@{variables('FileName')}",
        "headers": {
          "x-ms-blob-type": "BlockBlob",
          "Content-Type": "application/json",
          "x-ms-version": "2019-12-12"
        },
        "body": {
          "collectedAt": "@{utcNow()}",
          "subscriptionId": "@{parameters('subscriptionId')}",
          "recommendationCount": "@length(variables('AllRecommendations'))",
          "recommendations": "@variables('AllRecommendations')"
        },
        "authentication": {
          "type": "ManagedServiceIdentity",
          "identity": "${managed_identity_id}",
          "audience": "https://storage.azure.com/"
        }
      },
      "runAfter": {
        "Until_No_More_Pages": ["Succeeded"]
      }
    }
  },
  "outputs": {}
}