param logAnalyticsName string
param useExistingLogAnalytics bool = false
param existingLogAnalyticsName string = ''
param existingLogAnalyticsRG string = ''
param existingLogAnalyticsSubscriptionId string = ''
param apimApplicationInsightsName string
param apimApplicationInsightsDashboardName string
param functionApplicationInsightsName string
param functionApplicationInsightsDashboardName string
param foundryApplicationInsightsName string
param foundryApplicationInsightsDashboardName string
param location string = resourceGroup().location
param tags object = {}

@description('Create the APIM, Function/Logic App, and Foundry Application Insights resources.')
param createApplicationInsights bool = true

param createDashboard bool

// Networking
param usePrivateLinkScope bool = true
param privateLinkScopeName string
param vNetName string
param privateEndpointSubnetName string
param applicationInsightsDnsZoneName string

// Use existing network/dns zone - Legacy parameters (used when dnsZoneResourceId is not provided)
param dnsZoneRG string = ''
param dnsSubscriptionId string = ''
param vNetRG string

// New parameter: Direct DNS zone resource ID (preferred over dnsZoneRG/dnsSubscriptionId)
param dnsZoneResourceId string = ''
resource vnet 'Microsoft.Network/virtualNetworks@2022-01-01' existing = {
  name: vNetName
  scope: resourceGroup(vNetRG)
}

// Get existing subnet
resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' existing = {
  name: privateEndpointSubnetName
  parent: vnet
}

resource privateLinkScope 'microsoft.insights/privateLinkScopes@2021-07-01-preview' = if (usePrivateLinkScope) {
  name: privateLinkScopeName
  location: 'global'
  tags: tags
  properties: {
    accessModeSettings: {
      ingestionAccessMode: 'Open'
      queryAccessMode: 'Open'
    }
  }
}

module logAnalytics 'loganalytics.bicep' = {
  name: 'log-analytics'
  params: {
    name: logAnalyticsName
    location: location
    tags: tags
    privateLinkScopeName: usePrivateLinkScope ? privateLinkScopeName : ''
    useExistingLogAnalytics: useExistingLogAnalytics
    existingLogAnalyticsName: existingLogAnalyticsName
    existingLogAnalyticsRG: existingLogAnalyticsRG
    existingLogAnalyticsSubscriptionId: existingLogAnalyticsSubscriptionId
  }
}

// APIM App Insights
module apimApplicationInsights 'applicationinsights.bicep' = if (createApplicationInsights) {
  name: 'application-insights'
  params: {
    name: apimApplicationInsightsName
    location: location
    tags: tags
    dashboardName: apimApplicationInsightsDashboardName
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    privateLinkScopeName: usePrivateLinkScope ? privateLinkScopeName : ''
    createDashboard: createDashboard
  }
}

// Function App Insights
module functionApplicationInsights 'applicationinsights.bicep' = if (createApplicationInsights) {
  name: 'func-application-insights'
  params: {
    name: functionApplicationInsightsName
    location: location
    tags: tags
    dashboardName: functionApplicationInsightsDashboardName
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    privateLinkScopeName: usePrivateLinkScope ? privateLinkScopeName : ''
    createDashboard: createDashboard
  }
}

module foundryApplicationInsights 'applicationinsights.bicep' = if (createApplicationInsights) {
  name: 'foundry-application-insights'
  params: {
    name: foundryApplicationInsightsName
    location: location
    tags: tags
    dashboardName: foundryApplicationInsightsDashboardName
    logAnalyticsWorkspaceId: logAnalytics.outputs.id
    privateLinkScopeName: usePrivateLinkScope ? privateLinkScopeName : ''
    createDashboard: createDashboard
  }
}

module privateEndpoint '../networking/private-endpoint.bicep' = if (usePrivateLinkScope) {
  name: '${privateLinkScopeName}-pe'
  params: {
    groupIds: [
      'azuremonitor'
    ]
    dnsZoneName: applicationInsightsDnsZoneName
    name: '${privateLinkScopeName}-pe'
    privateLinkServiceId: privateLinkScope.id
    location: location
    dnsZoneRG: dnsZoneRG
    privateEndpointSubnetId: subnet.id
    dnsSubId: dnsSubscriptionId
    dnsZoneResourceId: dnsZoneResourceId
    enableDnsIntegration: usePrivateLinkScope
    tags: tags
  }
  dependsOn: [
    logAnalytics
  ]
}

output apimApplicationInsightsName string = createApplicationInsights ? apimApplicationInsights!.outputs.name : ''
output apimApplicationInsightsConnectionString string = createApplicationInsights ? apimApplicationInsights!.outputs.connectionString : ''
output apimApplicationInsightsInstrumentationKey string = createApplicationInsights ? apimApplicationInsights!.outputs.instrumentationKey : ''
output apimApplicationInsightsId string = createApplicationInsights ? apimApplicationInsights!.outputs.id : ''
output funcApplicationInsightsName string = createApplicationInsights ? functionApplicationInsights!.outputs.name : ''
output funcApplicationInsightsConnectionString string = createApplicationInsights ? functionApplicationInsights!.outputs.connectionString : ''
output funcApplicationInsightsInstrumentationKey string = createApplicationInsights ? functionApplicationInsights!.outputs.instrumentationKey : ''
output foundryApplicationInsightsName string = createApplicationInsights ? foundryApplicationInsights!.outputs.name : ''
output foundryApplicationInsightsConnectionString string = createApplicationInsights ? foundryApplicationInsights!.outputs.connectionString : ''
output foundryApplicationInsightsId string = createApplicationInsights ? foundryApplicationInsights!.outputs.id : ''
output foundryApplicationInsightsInstrumentationKey string = createApplicationInsights ? foundryApplicationInsights!.outputs.instrumentationKey : ''
output logAnalyticsWorkspaceId string = logAnalytics.outputs.id
output logAnalyticsWorkspaceName string = logAnalytics.outputs.name
