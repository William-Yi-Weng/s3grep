#!/bin/bash
set -e

if [ $# -ne 1 ]; then
  echo "Usage: $0 search_term"
  exit 1
fi

search_term=$1

# Clean folders
rm -fr ./tmp 
mkdir tmp


BUCKETS=$(aws s3 ls  | tr -s ' ' | awk '{print $3}')
TOTAL=$(aws s3 ls  | tr -s ' ' | awk '{print $3}'|wc -l)
    
echo "Total buckets $TOTAL..."

ITER=0
for buck in $BUCKETS
do
	
	ITER=$(expr $ITER + 1)
	echo "*********  Process: $ITER / $TOTAL *********"
  	echo "Reading files in bucket: $buck..."
	if [[ "$buck" == *"cloud"*"trail"* ]] || [[ "$buck" == *"access-logs"* ]]; then
	 	echo "Skip aws log buckets: $buck"
    	continue
  	fi

	sed -i -- "s/<s3.bucket>/$buck/g" s3grep.properties
	sed -i -- "s/<search_term>/$search_term/g" s3grep.properties

  	FILE="tmp/$buck.out"
  	echo "" > "tmp/$buck.out"
	
    
    # Execute scan for target bucket and store the console output
	java -jar target/s3-grep-1.0-SNAPSHOT.jar s3grep.properties > $FILE
	CONTENT=$(head -1 $FILE)
    tail -1 $FILE

	if [ "$CONTENT" != "" ]; then
        echo "Recording the messages containing the key word to the file...$FILE"
    else
    	rm -fr $FILE
        echo "Removing empty file...$FILE"
    fi
    
    sed -i -- "s/$buck/<s3.bucket>/g" s3grep.properties
    sed -i -- "s/$search_term/<search_term>/g" s3grep.properties
    sleep 3
    echo "**********  Finish Scan Task  **********"
done

echo "Finish reading objects... $ITER / $TOTAL"

