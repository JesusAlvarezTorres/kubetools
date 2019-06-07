#! /bin/bash
set -e

log_level() 
{ 
    case "$1" in
       -e) echo "$(date) [Error]  : " ${@:2}
          ;;
       -w) echo "$(date) [Warning]: " ${@:2}
          ;;       
       -i) echo "$(date) [Info]   : " ${@:2}
          ;;
       *)  echo "$(date) [Verbose]: " ${@:2}
          ;;
    esac
}


while [[ "$#" -gt 0 ]]

do

    case $1 in

        --tenant-id)

            TENANT_ID="$2"

            shift 2

        ;;

        --subscription-id)

            TENANT_SUBSCRIPTION_ID="$2"

            shift 2

        ;;

        --node-count)

            NODE_COUNT="$2"

            shift 2

        ;;
        *)

    esac

done



# Validate input

if [ -z "$TENANT_ID" ]

then

    echo ""

    echo "[ERR] --tenant-id is required"

    printUsage

fi



if [ -z "$TENANT_SUBSCRIPTION_ID" ]

then

    echo ""

    echo "[ERR] --subscription-id is required"

    printUsage

fi


if [ -z "$NODE_COUNT" ]

then

    echo ""

    echo "[ERR] --node-count is required"

    printUsage

fi



# Basic details of the system
log_level -i "Running  script as : $(whoami)"

log_level -i "System information: $(sudo uname -a)"


ROOT_PATH=/var/lib/waagent/custom-script/download/0
cd $ROOT_PATH

log_level -i "Getting Resource group and region"

export RESOURCE_GROUP=`ls -dt1 _output/* | head -n 1 | cut -d/ -f2 | cut -d. -f1`
export APIMODEL_FILE=$RESOURCE_GROUP.json

if [ $RESOURCE_GROUP == "" ] ; then
    log_level -i "Resource group not found.Scale can not be performed"
    exit 1
fi

cd $ROOT_PATH/_output

CLIENT_ID=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.servicePrincipalProfile.clientId'| tr -d '"')
FQDN_ENDPOINT_SUFFIX=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.customCloudProfile.environment.resourceManagerVMDNSSuffix' | tr -d '"')
IDENTITY_SYSTEM=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.customCloudProfile.identitySystem' | tr -d '"')
AUTH_METHOD=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.customCloudProfile.authenticationMethod' | tr -d '"')
ENDPOINT_ACTIVE_DIRECTORY_RESOURCEID=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.customCloudProfile.environment.serviceManagementEndpoint' | tr -d '"')
TENANT_ENDPOINT=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.customCloudProfile.environment.resourceManagerEndpoint' | tr -d '"')
ENDPOINT_ACTIVE_DIRECTORY_ENDPOINT=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.customCloudProfile.environment.activeDirectoryEndpoint' | tr -d '"')
ENDPOINT_GALLERY=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.customCloudProfile.environment.galleryEndpoint' | tr -d '"')
ENDPOINT_GRAPH_ENDPOINT=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.customCloudProfile.environment.graphEndpoint' | tr -d '"')
SUFFIXES_STORAGE_ENDPOINT=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.customCloudProfile.environment.storageEndpointSuffix' | tr -d '"')
SUFFIXES_KEYVAULT_DNS=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.customCloudProfile.environment.keyVaultDNSSuffix' | tr -d '"')
ENDPOINT_PORTAL=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.properties.customCloudProfile.portalURL' | tr -d '"')
REGION=$(cat $ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json | jq '.location' | tr -d '"')
AZURE_ENV="AzureStackCloud"
echo $TENANT_ENDPOINT
echo "CLIENT_ID: $CLIENT_ID"

if [ $CLIENT_ID == "" ] ; then
    log_level -i "Client ID not found.Scale can not be performed"
    exit 1
fi

if [ $REGION == "" ] ; then
    log_level -i "Region not found.Scale can not be performed"
    exit 1
fi

export CLIENT_ID=$CLIENT_ID
export CLIENT_SECRET=""
export NAME=$RESOURCE_GROUP
export REGION=$REGION
export TENANT_ID=$TENANT_ID
export SUBSCRIPTION_ID=$TENANT_SUBSCRIPTION_ID
export OUTPUT=$ROOT_PATH/_output/$RESOURCE_GROUP/apimodel.json
export AGENT_POOL="linuxpool"

echo "CLIENT_ID: $CLIENT_ID"
echo "NAME:$RESOURCE_GROUP"
echo "REGION:$REGION"
echo "TENANT_ID:$TENANT_ID"
echo "SUBSCRIPTION_ID:$TENANT_SUBSCRIPTION_ID"
echo "IDENTITY_SYSTEM:$IDENTITY_SYSTEM"
echo "NODE_COUNT:$NODE_COUNT"


cd $ROOT_PATH

CLIENT_SECRET=$(cat $ROOT_PATH/_output/$APIMODEL_FILE | jq '.properties.servicePrincipalProfile.secret' | tr -d '"')
export CLIENT_SECRET=$CLIENT_SECRET

if [ $CLIENT_SECRET == "" ] ; then
   log_level -i "Client Secret not found.Scale can not be performed"
   exit 1
fi

./bin/aks-engine scale \
        --azure-env $AZURE_ENV \
        --subscription-id $SUBSCRIPTION_ID \
        --api-model $OUTPUT \
        --location $REGION \
        --resource-group $RESOURCE_GROUP  \
        --master-FQDN $FQDN_ENDPOINT_SUFFIX \
        --node-pool $AGENT_POOL \
        --new-node-count $NODE_COUNT \
        --auth-method $AUTH_METHOD \
        --client-id $CLIENT_ID \
        --client-secret $CLIENT_SECRET \
        --identity-system $IDENTITY_SYSTEM || exit 1    
    

log_level -i "Scaling of kubernetes cluster completed."
