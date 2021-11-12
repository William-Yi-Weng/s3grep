#!/bin/bash
set -o errexit

if [[ "$#" -lt 1 ]] || [[ "$#" -gt 2 ]]; then
  echo "Usage: $0 <search_term> [folder_name(s)]"
  exit 1
fi

search_term="${1}"

# Clean folders
rm -fr ./tmp 
mkdir tmp

folders=()
IFS=':' read -ra temp_folder <<< "${2}"

for p in "${temp_folders[@]}"; do
	if [[ -n "${p}" ]]; then
		folders+=( "${p}" )
	fi
done

if [[ -z "${folders[@]}" ]]; then
	folders=$(aws s3 ls  | tr -s ' ' | awk '{print $3}')
fi
TOTAL=${#folders[@]}
    
echo "Total folders $TOTAL..."
echo ${folders[@]}

ITER=0
for folder in "${folders[@]}";
do
	cp s3grep.properties ./tmp/s3grep.properties
	ITER=$(expr $ITER + 1)
	echo "*********  Process: $ITER / $TOTAL *********"
  	echo "Reading files in folder: $folder..."

	sed -n "s/<scan.bucket>/$buck/g" ./tmp/s3grep.properties
	sed -n "s/<search_term>/$search_term/g" ./tmp/s3grep.properties

  	FILE="tmp/$buck.out"
  	echo "" > "tmp/$buck.out"
	
    
    # Execute scan for target bucket and store the console output
	java -jar target/s3-grep-1.0-SNAPSHOT.jar ./tmp/s3grep.properties > $FILE
	CONTENT=$(head -1 $FILE)
    tail -1 $FILE

	if [ "$CONTENT" != "" ]; then
        echo "Recording the messages containing the key word to the file...$FILE"
    else
    	rm -fr $FILE
        echo "Removing empty file...$FILE"
    fi
    
	rm -fr tmp/s3grep.properties
    sleep 3
    echo "**********  Finish Scan Task  **********"
done

echo "Finish reading objects... $ITER / $TOTAL"

