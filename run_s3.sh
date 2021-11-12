#!/bin/bash
set -o errexit

if [[ "$#" -lt 1 ]] || [[ "$#" -gt 2 ]]; then
  echo "Usage: $0 <search_term> [S3_bucket_name(s)]"
  exit 1
fi

search_term="${1}"

# Clean folders
rm -fr ./tmp 
mkdir tmp

BUCKETS=()
echo $S3_bucket
IFS=':' read -ra temp_S3_buckets <<< "${2}"

for p in "${temp_S3_buckets[@]}"; do
	if [[ -n "${p}" ]]; then
		BUCKETS+=( "${p}" )
	fi
done

if [[ -z "${BUCKETS[@]}" ]]; then
	BUCKETS=$(aws s3 ls  | tr -s ' ' | awk '{print $3}')
fi
TOTAL=${#BUCKETS[@]}
    
echo "Total buckets $TOTAL..."
echo ${BUCKETS[@]}

ITER=0
for buck in "${BUCKETS[@]}";
do
	cp s3grep.properties ./tmp/s3grep.properties
	ITER=$(expr $ITER + 1)
	echo "*********  Process: $ITER / $TOTAL *********"
  	echo "Reading files in bucket: $buck..."
	if [[ "$buck" == *"cloud"*"trail"* ]] || [[ "$buck" == *"access-logs"* ]]; then
	 	echo "Skip aws log buckets: $buck"
    	continue
  	fi

	sed -n "s/<s3.bucket>/$buck/g" ./tmp/s3grep.properties
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

