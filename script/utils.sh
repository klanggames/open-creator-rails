DEPLOYMENTS_FILE="deployments.json"

function get_address() {
    contract_name=$1

    address=$(jq -r --arg name "$contract_name" '.[$name]' $DEPLOYMENTS_FILE)

    echo $address
}