import json
import logging

# Set up logging to CloudWatch
logger = logging.getLogger()
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # Log the event that triggered the Lambda function
    logger.info("Event received: " + json.dumps(event))

    # Extract details (e.g., bucket name, object key)
    try:
        bucket_name = event['Records'][0]['s3']['bucket']['name']
        object_key = event['Records'][0]['s3']['object']['key']

        # Log the bucket and object details
        logger.info(f"File uploaded to {bucket_name}/{object_key}")
        
        # You can add any additional processing logic here if required
        
    except KeyError as e:
        logger.error(f"Error processing event: Missing key {str(e)}")
        raise e

    # Return a response (can be customized based on your use case)
    return {
        'statusCode': 200,
        'body': json.dumps(f'Event processed successfully! File uploaded to {bucket_name}/{object_key}')
    }
