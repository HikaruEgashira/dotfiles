#!/bin/bash

loggedInUser=$(stat -f "%Su" /dev/console)
codePath="/Applications/Visual Studio Code.app/Contents/Resources/app/bin/code"
cd /Users/"$loggedInUser"
codeExtensions=$(sudo -u "$loggedInUser" "$codePath" --list-extensions)
highRiskFound=0

jsonResult="{\"extensions\":["

# Read the extensions into an array
IFS=$'\n' read -rd '' -a extensions <<<"$codeExtensions"

for line in "${extensions[@]}"; do
  # echo "Scanning $line"
  content=$(curl -s --location 'https://app.extensiontotal.com/api/getExtensionRisk' \
  --header 'Content-Type: application/json' \
  --header 'Cookie: SameSite=None' \
  --header 'x-api-key: '"$EXTENSIONTOTAL_API_KEY"'' \
  --header 'X-Origin: Extension' \
  --data "{
    \"q\": \"$line\"
  }")
  jsonResult+="$content,"

  risk=$(echo "$content" | jq .risk)
  if [ $(echo "$risk > 5.0" | bc) -eq 1 ]; then
    echo "High risk extension found: $line"
    highRiskFound=1
  fi
done

OUTPUT="vscode-extensions.json"

jsonResult=${jsonResult%,}
jsonResult+="]}"
echo "$jsonResult" > "$OUTPUT"
bunx @biomejs/biome format $OUTPUT --fix > /dev/null

if [ $highRiskFound -eq 0 ]; then
  echo "No high risk extensions found"
fi
