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
    "advisorContainerName": {
      "type": "String",
      "defaultValue": "${advisor_container_name}"
    },
    "reservationContainerName": {
      "type": "String",
      "defaultValue": "${reservation_container_name}"
    },
    "savingsplanContainerName": {
      "type": "String",
      "defaultValue": "${savingsplan_container_name}"
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
    "Initialize_AdvisorFileName": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "AdvisorFileName",
            "type": "String",
            "value": "@{concat('advisor-recommendations-', variables('CurrentDate'), '.json')}"
          }
        ]
      },
      "runAfter": {
        "Initialize_CurrentDate": ["Succeeded"]
      }
    },
    "Initialize_ReservationFileName": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "ReservationFileName",
            "type": "String",
            "value": "@{concat('reservation-recommendations-', variables('CurrentDate'), '.json')}"
          }
        ]
      },
      "runAfter": {
        "Initialize_AdvisorFileName": ["Succeeded"]
      }
    },
    "Initialize_SavingsPlanFileName": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "SavingsPlanFileName",
            "type": "String",
            "value": "@{concat('savingsplan-recommendations-', variables('CurrentDate'), '.json')}"
          }
        ]
      },
      "runAfter": {
        "Initialize_ReservationFileName": ["Succeeded"]
      }
    },
    "Initialize_AdvisorRecommendations": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "AdvisorRecommendations",
            "type": "Array",
            "value": []
          }
        ]
      },
      "runAfter": {
        "Initialize_SavingsPlanFileName": ["Succeeded"]
      }
    },
    "Initialize_ReservationRecommendations": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "ReservationRecommendations",
            "type": "Array",
            "value": []
          }
        ]
      },
      "runAfter": {
        "Initialize_AdvisorRecommendations": ["Succeeded"]
      }
    },
    "Initialize_SavingsPlanRecommendations": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "SavingsPlanRecommendations",
            "type": "Array",
            "value": []
          }
        ]
      },
      "runAfter": {
        "Initialize_ReservationRecommendations": ["Succeeded"]
      }
    },
    "Initialize_AdvisorNextLink": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "AdvisorNextLink",
            "type": "String",
            "value": "https://management.azure.com/subscriptions/@{parameters('subscriptionId')}/providers/Microsoft.Advisor/recommendations?api-version=2020-01-01"
          }
        ]
      },
      "runAfter": {
        "Initialize_SavingsPlanRecommendations": ["Succeeded"]
      }
    },
    "Initialize_ReservationNextLink": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "ReservationNextLink",
            "type": "String",
            "value": "https://management.azure.com/subscriptions/@{parameters('subscriptionId')}/providers/Microsoft.Consumption/reservationRecommendations?api-version=2023-05-01"
          }
        ]
      },
      "runAfter": {
        "Initialize_AdvisorNextLink": ["Succeeded"]
      }
    },
    "Initialize_SavingsPlanNextLink": {
      "type": "InitializeVariable",
      "inputs": {
        "variables": [
          {
            "name": "SavingsPlanNextLink",
            "type": "String",
            "value": "https://management.azure.com/subscriptions/@{parameters('subscriptionId')}/providers/Microsoft.CostManagement/benefitRecommendations?api-version=2025-03-01&$filter=properties/lookBackPeriod eq 'Last60Days' and properties/term eq 'P3Y' and properties/scope eq 'Single'"
          }
        ]
      },
      "runAfter": {
        "Initialize_ReservationNextLink": ["Succeeded"]
      }
    },
    "Until_No_More_Advisor_Pages": {
      "type": "Until",
      "expression": "@equals(variables('AdvisorNextLink'), '')",
      "limit": {
        "count": 100,
        "timeout": "PT10M"
      },
      "actions": {
        "Get_Advisor_Page": {
          "type": "Http",
          "inputs": {
            "method": "GET",
            "uri": "@variables('AdvisorNextLink')",
            "authentication": {
              "type": "ManagedServiceIdentity",
              "identity": "${managed_identity_id}"
            }
          },
          "runAfter": {}
        },
        "Parse_Advisor_Response": {
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
        "Append_Advisor_Recommendations": {
          "type": "Foreach",
          "foreach": "@body('Parse_Advisor_Response')?['value']",
          "actions": {
            "Append_Single_Advisor_Recommendation": {
              "type": "AppendToArrayVariable",
              "inputs": {
                "name": "AdvisorRecommendations",
                "value": "@items('Append_Advisor_Recommendations')"
              }
            }
          },
          "runAfter": {
            "Parse_Advisor_Response": ["Succeeded"]
          }
        },
        "Update_Advisor_NextLink": {
          "type": "SetVariable",
          "inputs": {
            "name": "AdvisorNextLink",
            "value": "@{coalesce(body('Parse_Advisor_Response')?['nextLink'], '')}"
          },
          "runAfter": {
            "Append_Advisor_Recommendations": ["Succeeded", "Failed", "Skipped"]
          }
        }
      },
      "runAfter": {
        "Initialize_SavingsPlanNextLink": ["Succeeded"]
      }
    },
    "Until_No_More_Reservation_Pages": {
      "type": "Until",
      "expression": "@equals(variables('ReservationNextLink'), '')",
      "limit": {
        "count": 100,
        "timeout": "PT10M"
      },
      "actions": {
        "Get_Reservation_Page": {
          "type": "Http",
          "inputs": {
            "method": "GET",
            "uri": "@variables('ReservationNextLink')",
            "authentication": {
              "type": "ManagedServiceIdentity",
              "identity": "${managed_identity_id}"
            }
          },
          "runAfter": {}
        },
        "Parse_Reservation_Response": {
          "type": "ParseJson",
          "inputs": {
            "content": "@body('Get_Reservation_Page')",
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
            "Get_Reservation_Page": ["Succeeded"]
          }
        },
        "Append_Reservation_Recommendations": {
          "type": "Foreach",
          "foreach": "@body('Parse_Reservation_Response')?['value']",
          "actions": {
            "Append_Single_Reservation_Recommendation": {
              "type": "AppendToArrayVariable",
              "inputs": {
                "name": "ReservationRecommendations",
                "value": "@items('Append_Reservation_Recommendations')"
              }
            }
          },
          "runAfter": {
            "Parse_Reservation_Response": ["Succeeded"]
          }
        },
        "Update_Reservation_NextLink": {
          "type": "SetVariable",
          "inputs": {
            "name": "ReservationNextLink",
            "value": "@{coalesce(body('Parse_Reservation_Response')?['nextLink'], '')}"
          },
          "runAfter": {
            "Append_Reservation_Recommendations": ["Succeeded", "Failed", "Skipped"]
          }
        }
      },
      "runAfter": {
        "Until_No_More_Advisor_Pages": ["Succeeded", "Failed", "Skipped", "TimedOut"]
      }
    },
    "Until_No_More_SavingsPlan_Pages": {
      "type": "Until",
      "expression": "@equals(variables('SavingsPlanNextLink'), '')",
      "limit": {
        "count": 100,
        "timeout": "PT10M"
      },
      "actions": {
        "Get_SavingsPlan_Page": {
          "type": "Http",
          "inputs": {
            "method": "GET",
            "uri": "@variables('SavingsPlanNextLink')",
            "authentication": {
              "type": "ManagedServiceIdentity",
              "identity": "${managed_identity_id}"
            }
          },
          "runAfter": {}
        },
        "Parse_SavingsPlan_Response": {
          "type": "ParseJson",
          "inputs": {
            "content": "@body('Get_SavingsPlan_Page')",
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
            "Get_SavingsPlan_Page": ["Succeeded"]
          }
        },
        "Append_SavingsPlan_Recommendations": {
          "type": "Foreach",
          "foreach": "@body('Parse_SavingsPlan_Response')?['value']",
          "actions": {
            "Append_Single_SavingsPlan_Recommendation": {
              "type": "AppendToArrayVariable",
              "inputs": {
                "name": "SavingsPlanRecommendations",
                "value": "@items('Append_SavingsPlan_Recommendations')"
              }
            }
          },
          "runAfter": {
            "Parse_SavingsPlan_Response": ["Succeeded"]
          }
        },
        "Update_SavingsPlan_NextLink": {
          "type": "SetVariable",
          "inputs": {
            "name": "SavingsPlanNextLink",
            "value": "@{coalesce(body('Parse_SavingsPlan_Response')?['nextLink'], '')}"
          },
          "runAfter": {
            "Append_SavingsPlan_Recommendations": ["Succeeded", "Failed", "Skipped"]
          }
        }
      },
      "runAfter": {
        "Until_No_More_Reservation_Pages": ["Succeeded", "Failed", "Skipped", "TimedOut"]
      }
    },
    "Create_Advisor_JSON_Blob": {
      "type": "Http",
      "inputs": {
        "method": "PUT",
        "uri": "https://@{parameters('storageAccountName')}.blob.core.windows.net/@{parameters('advisorContainerName')}/@{variables('AdvisorFileName')}",
        "headers": {
          "x-ms-blob-type": "BlockBlob",
          "Content-Type": "application/json",
          "x-ms-version": "2019-12-12"
        },
        "body": {
          "collectedAt": "@{utcNow()}",
          "subscriptionId": "@{parameters('subscriptionId')}",
          "recommendationCount": "@length(variables('AdvisorRecommendations'))",
          "recommendations": "@variables('AdvisorRecommendations')"
        },
        "authentication": {
          "type": "ManagedServiceIdentity",
          "identity": "${managed_identity_id}",
          "audience": "https://storage.azure.com/"
        }
      },
      "runAfter": {
        "Until_No_More_SavingsPlan_Pages": ["Succeeded", "Failed", "Skipped", "TimedOut"]
      }
    },
    "Create_Reservation_JSON_Blob": {
      "type": "Http",
      "inputs": {
        "method": "PUT",
        "uri": "https://@{parameters('storageAccountName')}.blob.core.windows.net/@{parameters('reservationContainerName')}/@{variables('ReservationFileName')}",
        "headers": {
          "x-ms-blob-type": "BlockBlob",
          "Content-Type": "application/json",
          "x-ms-version": "2019-12-12"
        },
        "body": {
          "collectedAt": "@{utcNow()}",
          "subscriptionId": "@{parameters('subscriptionId')}",
          "recommendationCount": "@length(variables('ReservationRecommendations'))",
          "recommendations": "@variables('ReservationRecommendations')"
        },
        "authentication": {
          "type": "ManagedServiceIdentity",
          "identity": "${managed_identity_id}",
          "audience": "https://storage.azure.com/"
        }
      },
      "runAfter": {
        "Create_Advisor_JSON_Blob": ["Succeeded", "Failed", "Skipped", "TimedOut"]
      }
    },
    "Create_SavingsPlan_JSON_Blob": {
      "type": "Http",
      "inputs": {
        "method": "PUT",
        "uri": "https://@{parameters('storageAccountName')}.blob.core.windows.net/@{parameters('savingsplanContainerName')}/@{variables('SavingsPlanFileName')}",
        "headers": {
          "x-ms-blob-type": "BlockBlob",
          "Content-Type": "application/json",
          "x-ms-version": "2019-12-12"
        },
        "body": {
          "collectedAt": "@{utcNow()}",
          "subscriptionId": "@{parameters('subscriptionId')}",
          "recommendationCount": "@length(variables('SavingsPlanRecommendations'))",
          "recommendations": "@variables('SavingsPlanRecommendations')"
        },
        "authentication": {
          "type": "ManagedServiceIdentity",
          "identity": "${managed_identity_id}",
          "audience": "https://storage.azure.com/"
        }
      },
      "runAfter": {
        "Create_Reservation_JSON_Blob": ["Succeeded", "Failed", "Skipped", "TimedOut"]
      }
    }
  },
  "outputs": {}
}