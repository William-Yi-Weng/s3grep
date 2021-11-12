## Description
A tool to search similar to grep S3 buckets for particular strings or regular expressions. This searches in parallel. Files are streamed to the local machine, searched, and discarded meaning you will not need a massive amount of space to search a large S3 bucket.

## Build
This project is using maven build.
```mvn install```

This utilizes maven and to package the jar simply run mvn package. From there it can be run via 
```java -jar s3-grep-1.0-SNAPSHOT.jar s3grep.properties```
The s3grep.properties contains all configuration options. Moved to use environment variables or profiles instead of aws_access_id and aws_access_key properties. 

## How to use
The script is using for batch scan the target buckets or all the buckets under your account, which is using with searching pattern of 'password' in this example:
```sh run.sh password bucket1:bucket2:bucket3```
or
```sh run.sh password``` -- scan all s3 bucket over the current account


The original author is from https://github.com/Setfive/s3grep
More information at http://shout.setfive.com/2016/10/04/s3grep-searching-s3-files-and-buckets/