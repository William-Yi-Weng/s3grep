package main.java;

import com.amazonaws.auth.EnvironmentVariableCredentialsProvider;
import com.amazonaws.services.s3.AmazonS3Client;
import com.amazonaws.services.s3.model.ListObjectsRequest;
import com.amazonaws.services.s3.model.ObjectListing;
import com.amazonaws.services.s3.model.S3Object;

import java.io.BufferedReader;
import java.io.FileInputStream;
import java.io.InputStream;
import java.io.InputStreamReader;
import java.util.Properties;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

import org.apache.log4j.ConsoleAppender;
import org.apache.log4j.Level;
import org.apache.log4j.Logger;
import org.apache.log4j.PatternLayout;
import org.apache.log4j.RollingFileAppender;

public class S3Grep implements Runnable {

    private static Logger logger = Logger.getLogger(S3Grep.class);
    private static Properties configuration = new Properties();
    private static AmazonS3Client s3Client;
    private static Pattern patternMatcher;
    private String fileKey;


    public static void main(String[] args) throws Exception {
        logger.removeAllAppenders();

        if(args.length != 1) {
            throw new Exception("You must pass through one argument, the configuration file. Exiting");
        }


        configuration.load(new FileInputStream(args[0]));
        checkConfiguration();

        ConsoleAppender console = new ConsoleAppender();
        console.setThreshold(Level.toLevel( configuration.getProperty("log_level") != null ? configuration.getProperty("log_level")  : "INFO") );
        console.setLayout(new PatternLayout( configuration.getProperty("logger_pattern") != null ? configuration.getProperty("logger_pattern")  : "%d{dd MMM yyyy HH:mm:ss} [%p] %m%n"));
        console.activateOptions();
        logger.addAppender(console);

        if(isRegexSearch()) {
            patternMatcher = Pattern.compile(configuration.getProperty("search_term"));
        }

        s3Client = new AmazonS3Client( new EnvironmentVariableCredentialsProvider());

        ExecutorService searchPool = Executors.newFixedThreadPool(getSearchThreads());

        ObjectListing listing;
        ListObjectsRequest listingRequest = new ListObjectsRequest().withBucketName( (String)configuration.getProperty("scan_bucket") );

        do {

            listing = s3Client.listObjects(listingRequest);

            listing.getObjectSummaries().forEach((object) -> {
                searchPool.submit(new S3Grep(object.getKey()));
            });

            listingRequest.setMarker(listing.getNextMarker());

        }while(listing.isTruncated());

        logger.debug("All files added to search pool executor service");

        searchPool.shutdown();
        logger.debug("Shutdown the search pool");

        while(!searchPool.isTerminated());

        logger.debug("Search pool is terminated.");


    }

    public S3Grep(String fileKey) {
        this.fileKey = fileKey;
    }


    public void run() {

        logger.debug("Checking file: " + fileKey);
        S3Object object = s3Client.getObject(configuration.getProperty("scan_bucket"),fileKey);

        try(
                InputStream content = object.getObjectContent();
                BufferedReader reader = new BufferedReader(new InputStreamReader(content));
        ){

            String line;
            String searchTerm = configuration.getProperty("search_term");

            int lineNumber = 0;
            while ( (line = reader.readLine()) != null ) {
                lineNumber++;
                String pattern = "";

                if( patternMatcher != null && patternMatcher.matcher(line).matches()) {

                    // Cut previous and forward 80 chars of key words
                    int previousIndex = line.toLowerCase().indexOf(pattern.toLowerCase())-80;
                    int forwardIndex = line.toLowerCase().indexOf(pattern.toLowerCase())+80;
                    int startPoint = line.toLowerCase().indexOf(pattern.toLowerCase()) <80? 0: previousIndex;
                    int endPoint = line.length() <forwardIndex? line.length(): forwardIndex;

                    logger.info(fileKey + ":" + lineNumber + ":" + line.substring(startPoint,endPoint));
                }


            }


        }catch(Exception e) {
            e.printStackTrace();
        }


    }


    private static void checkConfiguration() throws Exception
    {
        if(configurationValueExists("scan_bucket") == false) {
            throw new Exception("You must set your s3 bucket for the search");
        }

        if(configurationValueExists("search_term") == false) {
            throw new Exception("You must set the search term");
        }
    }

    private static int getSearchThreads() {
        if(configurationValueExists("search_threads")) {
            return Integer.valueOf(configuration.getProperty("search_threads"));
        }

        return Runtime.getRuntime().availableProcessors();
    }

    private static boolean isRegexSearch() {
        if(configurationValueExists("is_regex_search")) {
            return configuration.getProperty("is_regex_search").trim().equals("true");
        }

        return false;
    }


    private static boolean configurationValueExists(String key)
    {
        String prop = configuration.getProperty(key);
        return prop == null || prop.trim().equals("") ? false : true;
    }

}