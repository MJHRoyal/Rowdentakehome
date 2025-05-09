import boto3
import logging

# Create EC2 client
ec2 = boto3.client('ec2')

def lambda_handler(event, context):
    # Define the name substring to search for
    MATCH_STRING = "RowdensTEST - holden"
    
    try:
        # Get all running instances with their tags
        response = ec2.describe_instances(
            Filters=[{'Name': 'instance-state-name', 'Values': ['running']}]
        )
        
        # Iterate over reservations and instances
        for reservation in response['Reservations']:
            for instance in reservation['Instances']:
                # Check for 'Name' tag and match string
                name = next((tag['Value'] for tag in instance.get('Tags', []) if tag['Key'] == 'Name'), '')
                if MATCH_STRING in name:
                    # Stop the instance if the name matches
                    logging.info(f"Stopping instance {instance['InstanceId']} ({name})")
                    ec2.stop_instances(InstanceIds=[instance['InstanceId']])
                    logging.info(f"Instance {instance['InstanceId']} stopped.")
        
        return {
            'statusCode': 200,
            'body': 'Lambda execution completed successfully'
        }
    
    except Exception as e:
        logging.error(f"Error stopping instances: {str(e)}")
        return {
            'statusCode': 500,
            'body': f'Error: {str(e)}'
        }

