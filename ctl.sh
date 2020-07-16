#!/bin/bash
#
# Copyright (c) AppDynamics Inc
# All rights reserved
#
# Maintainer: David Ryder, david.ryder@appdynamics.com, July-2020
#
# AppDynamics AWS Lambda Mini Lab
#
# Requries: jq (brew install jq)
#
cmd=${1:-"unknown"}
OS_TYPE=`uname -s`


# Bash, AWS and Java Aoo Test Utility Functions
#. Scripts/bash-functions.sh
#. Scripts/aws-functions.sh
#. Scripts/test-functions.sh

# Environment Variables Source
. envvars.sh

# Commands
if [ $cmd == "test" ]; then
  echo "Test"

# New for MINI LAB
elif [ $cmd == "createUserGroup" ]; then
  aws iam create-group --group-name $AWS_CLOUD9_GROUP_NAME
  aws iam create-user  --user-name  $AWS_CLOUD9_USER_NAME
  aws iam add-user-to-group --user-name $AWS_CLOUD9_USER_NAME --group-name $AWS_CLOUD9_GROUP_NAME

  # https://docs.aws.amazon.com/cloud9/latest/user-guide/auth-and-access-control.html
  #                 "arn:aws:iam::aws:policy/AdministratorAccess" \
  POLICY_LIST=("arn:aws:iam::aws:policy/AWSCloud9EnvironmentMember" \
               "arn:aws:iam::aws:policy/AWSCloud9Administrator" \
               "arn:aws:iam::aws:policy/AWSCloud9User" \
               "arn:aws:iam::aws:policy/AWSCloud9SSMInstanceProfile" \
               "arn:aws:iam::aws:policy/AmazonLambdaRolePolicyForLaunchWizardSAP" \
               "arn:aws:iam::aws:policy/AWSLambdaFullAccess" \
               "arn:aws:iam::aws:policy/AmazonAPIGatewayAdministrator" \
               "arn:aws:iam::aws:policy/AmazonAPIGatewayInvokeFullAccess" )
  for POLICY in "${POLICY_LIST[@]}"; do
    echo "Adding Policy $POLICY to Group $AWS_CLOUD9_GROUP_NAME"
    aws iam attach-group-policy --policy-arn $POLICY --group-name $AWS_CLOUD9_GROUP_NAME
  done

  # Setup Cloud9LambdaAccessGroup
  # https://docs.aws.amazon.com/cloud9/latest/user-guide/lambda-functions.html
  # https://docs.aws.amazon.com/cloud9/latest/user-guide/samples/Cloud9LambdaAccessGroup.zip
  if [ ! -f $AWS_CLOUD_LAMBDA_ACCESS_GROUP_FILE.yaml ]; then
    curl https://docs.aws.amazon.com/cloud9/latest/user-guide/samples/$AWS_CLOUD_LAMBDA_ACCESS_GROUP_FILE.zip \
        --output $AWS_CLOUD_LAMBDA_ACCESS_GROUP_FILE.zip
        unzip $AWS_CLOUD_LAMBDA_ACCESS_GROUP_FILE.zip
  fi
  aws cloudformation create-stack \
    --stack-name $AWS_CLOUD_LAMBDA_ACCESS_GROUP_NAME \
    --template-body file://$AWS_CLOUD_LAMBDA_ACCESS_GROUP_FILE.yaml \
    --parameters ParameterKey=GroupName,ParameterValue=$AWS_CLOUD9_GROUP_NAME \
    --capabilities CAPABILITY_NAMED_IAM

  # Create random Password unless already provided
  AWS_CLOUD9_USER_PWD=${AWS_CLOUD9_USER_PWD:-$(openssl rand -base64 16 | tr -dc A-Z-a-z-0-9)}
  aws iam create-login-profile --user-name $AWS_CLOUD9_USER_NAME --password $AWS_CLOUD9_USER_PWD --no-password-reset-required
  echo "Created User $AWS_CLOUD9_USER_NAME with Password $AWS_CLOUD9_USER_PWD"

elif [ $cmd = "cloud9List" ]; then
  aws cloud9 list-environments

elif [ $cmd = "cloud9CreateEnv" ]; then
  USER_ARN=`aws iam get-user --user-name $AWS_CLOUD9_USER_NAME --query "User.Arn" --output text`
  aws cloud9 create-environment-ec2 \
      --name $AWS_CLOUD9_ENV_NAME \
      --description "AWS_CLOUD9_ENV_NAME" \
      --instance-type t2.micro \
      --automatic-stop-time-minutes 60 --owner-arn $USER_ARN

elif [ $cmd = "cloud9deleteAllEnv" ]; then
  aws cloud9 list-environments --query environmentIds
  LIST1=$(aws cloud9 list-environments --query environmentIds --output text)
  echo $LIST1
  for ENV_ID in $LIST1; do
    echo "Delete Cloud 9 Environment $ENV_ID"
    aws cloud9 delete-environment --environment-id $ENV_ID
  done

elif [ $cmd == "deleteUserGroup" ]; then
  aws iam remove-user-from-group --group-name $AWS_CLOUD9_GROUP_NAME --user-name $AWS_CLOUD9_USER_NAME
  aws iam delete-login-profile --user-name $AWS_CLOUD9_USER_NAME
  aws iam delete-user --user-name $AWS_CLOUD9_USER_NAME
  aws iam get-group --group-name $AWS_CLOUD9_GROUP_NAME
  aws iam list-attached-group-policies --group-name $AWS_CLOUD9_GROUP_NAME
  LIST1=$(aws iam list-attached-group-policies --group-name $AWS_CLOUD9_GROUP_NAME --query AttachedPolicies[].PolicyArn --output text)
  for POLICY_ARN in $LIST1; do
    echo "Deteching Policy $POLICY_ARN from Group $AWS_CLOUD9_GROUP_NAME"
    aws iam detach-group-policy --group-name $AWS_CLOUD9_GROUP_NAME  --policy-arn $POLICY_ARN
  done
  aws iam delete-group-policy --policy-name $AWS_CLOUD_LAMBDA_ACCESS_GROUP_NAME --group-name $AWS_CLOUD9_GROUP_NAME
  aws iam delete-group --group-name $AWS_CLOUD9_GROUP_NAME
  aws cloudformation delete-stack --stack-name $AWS_CLOUD_LAMBDA_ACCESS_GROUP_NAME

elif [ $cmd == "listFunctions" ]; then
  aws lambda list-functions | jq -r '[.Functions[] | {FunctionName, Runtime, Handler, FunctionArn}  ]'

elif [ $cmd == "lambdaDeleteAllFunctions" ]; then
  LIST1=$(aws lambda list-functions --query Functions[].FunctionName --output text)
  echo $LIST1
  for FN_NAME in $LIST1; do
    echo "Delete Lambda Function $FN_NAME"
    aws lambda delete-function --function-name $FN_NAME
  done
elif [ $cmd == "invokeFunction" ]; then
   aws lambda invoke --function-name $AWS_LAMBDA_FUNCTION_NAME --payload "$APPD_POST_DATA" /dev/stdout

elif [ $cmd == "updateFunctionCode" ]; then
  aws lambda update-function-code --function-name $AWS_LAMBDA_FUNCTION_NAME --zip-file fileb://$AWS_LAMBDA_ZIP_FILE

elif [ $cmd == "updateFunctionHandler" ]; then
  HANDLER=${2:-"$AWS_LAMBDA_HANDLER"}
  aws lambda update-function-configuration --function-name $AWS_LAMBDA_FUNCTION_NAME --handler $HANDLER

elif [ $cmd == "deleteFunction" ]; then
  FN_NAME=${2:-"$AWS_LAMBDA_FUNCTION_NAME"}
  aws lambda delete-function --function-name $FN_NAME
  aws iam delete-role --role-name $AWS_LAMBDA_ROLE_NAME

elif [ $cmd == "configureAppDynamicsLambda" ]; then
  _awsLambdaConfigureAppDynamics

elif [ $cmd == "createRestApi" ]; then
  _awsCreateRestAPI

elif [ $cmd == "listRestApi" ]; then
  aws apigateway get-rest-apis | jq -r '.items[] | {name, id}'

elif [ $cmd == "deleteRestApi" ]; then
  AWS_REST_API_ID=`aws apigateway get-rest-apis  | jq --arg SEARCH_STR $AWS_API_NAME -r '.items[] | select(.name | test($SEARCH_STR)) |  .id'`
  echo "Deleting $AWS_API_NAME ID: ($AWS_REST_API_ID)"
  aws apigateway delete-rest-api --rest-api-id $AWS_REST_API_ID

elif [ $cmd == "testRestApiCurl" ]; then
  # Test call to API Gateway and invoke Lamnda Function using curl
  _awsTestPostApiCurl

elif [ $cmd == "testRestApiCurlError" ]; then
  # Test call to API Gateway and invoke Lamnda Function using curl
  # Trigger the Lambda function to error
  INTERATIONS_N=${2:-1}
  INTERVAL_SEC=${3:-1}
  _awsTestPostApiCurlError $INTERATIONS_N $INTERVAL_SEC

elif [ $cmd == "testRestApiJavaApp" ]; then
  # Test call to API Gateway using the Java App
  _awsTestPostApiJavaApp

elif [ $cmd == "startJavaApp" ]; then
  _startJavaApp

elif [ $cmd == "runJavaApp" ]; then
  _stopJavaApp
  nohup java -jar $JAVA_TEST_APP_JAR 18081 &
  _tailLog 15 nohup.out

elif [ $cmd == "stopJavaApp" ]; then
  _stopJavaApp

elif [ $cmd == "loadGenJavaApp" ]; then
  _testJavaAppLoadGen1 &

elif [ $cmd == "installJq" ]; then
  if [ "$OS_TYPE" == "Darwin" ]; then
      brew install jq
  elif [ "$OS_TYPE" == "Linux" ]; then
      sudo apt-get install jq
  else
      echo "Unknown OS TYPE: $OS_TYPE"
  fi

elif [ $cmd == "installAwsCli" ]; then
  if [ "$OS_TYPE" == "Darwin" ]; then
    # https://docs.aws.amazon.com/cli/latest/userguide/install-macos.html
    curl "https://s3.amazonaws.com/aws-cli/awscli-bundle.zip" -o "awscli-bundle.zip"
    unzip awscli-bundle.zip
    sudo ./awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
    sudo /usr/local/bin/python awscli-bundle/install -i /usr/local/aws -b /usr/local/bin/aws
    aws --version
  elif [ "$OS_TYPE" == "Linux" ]; then
    sudo apt-get install awscli
  else
    echo "Unknown OS TYPE: $OS_TYPE"
  fi

elif [ $cmd == "installMaven" ]; then
  # https://maven.apache.org/download.cgi
  _validateEnvironmentVars "Installing Apache Maven" \
    "MAVEN_APACHE_DOWNLOAD_MIRROR" "MAVEN_DOWNLOAD_FILE"
  MVN_WHICH=`which mvn`
  if [ "$MVN_WHICH" == "" ]; then
    echo "Downloading Maven locally: $DOWNLOAD_URL"
    # Maven is not installed - download locally into this directory
    DOWNLOAD_URL=http://$MAVEN_APACHE_DOWNLOAD_MIRROR/maven/maven-3/3.6.2/binaries/$MAVEN_DOWNLOAD_FILE
    curl  $DOWNLOAD_URL --output $MAVEN_DOWNLOAD_FILE
    tar xf $MAVEN_DOWNLOAD_FILE
  else
    echo "Maven already installed: $MVN_WHICH"
  fi
  # Find MAVEN_PATH
  #if [ "`which mvn`" == "" ]; then MVN_BIN=`pwd`"/$MAVEN_BASE_FILE/bin"; else MVN_BIN=`which mvn`; fi
  #MAVEN_PATH=`pwd`"/$MAVEN_BASE_FILE/bin"
  #echo "set PATH to Maven"
  #echo ' export MAVEN_PATH=`pwd`/$MAVEN_BASE_FILE/bin'
  #echo ' export PATH=$MAVEN_PATH:$PATH'

elif [ $cmd == "buildLambda" ]; then
  _validateEnvironmentVars "Build Lambda Function" "MAVEN_BASE_FILE"
  # Find MAVEN_PATH
  if [ "`which mvn`" == "" ]; then MVN_BIN=`pwd`"/$MAVEN_BASE_FILE/bin/mvn"; else MVN_BIN=`which mvn`; fi
  #MVN_BIN=`pwd`"/$MAVEN_BASE_FILE/bin/mvn"
  $MVN_BIN -f LambdaFunction/pom.xml clean package shade:shade
  # Built LambdaFunction/target/LambdaFunction-0.0.1-SNAPSHOT.jar

elif [ $cmd == "buildJavaApp" ]; then
  _validateEnvironmentVars "Build Java App" "MAVEN_BASE_FILE"
  # Find MAVEN_PATH
  if [ "`which mvn`" == "" ]; then MVN_BIN=`pwd`"/$MAVEN_BASE_FILE/bin/mvn"; else MVN_BIN=`which mvn`; fi
  #MVN_BIN=`pwd`"/$MAVEN_BASE_FILE/bin/mvn"
  $MVN_BIN -f JavaApp/pom.xml clean package
  # Built LambdaFunction/target/LambdaFunction-0.0.1-SNAPSHOT.jar

elif [ $cmd == "dockerBuild" ]; then
  # Copy in AppDynamcis agents
  # Ensure Dockerfile includes these files
  cp -n ~/Downloads/AppD-Downloads/AppServerAgent-4.5.15.28231.zip .
  cp -n ~/Downloads/AppD-Downloads/MachineAgent-4.5.14.2293.zip .
  cp -n ~/Downloads/AppD-Downloads/awslambdamonitor-2.0.1.zip .
  ls -al *.zip
  #
  docker build -t $DOCKER_IMAGE_NAME .

elif [ $cmd == "dockerRun" ]; then
  docker run -d $DOCKER_IMAGE_NAME
  docker ps

elif [ $cmd == "dockerBash" ]; then
  # Connect to the containe with bash
  DOCKER_IMAGE_ID=`docker container ps --format '{{json .}}' | jq --arg SEARCH_STR $DOCKER_IMAGE_NAME -r '. | select(.Image | test($SEARCH_STR)) | .ID'`
  docker exec -it $DOCKER_IMAGE_ID /bin/bash

elif [ $cmd == "test1" ]; then
  _test1 A B C

else
  echo ""
  echo "Commands: "
  echo "  createFunction        Create an AWS Lambda function"
  echo "  listFunctions         List Lambda functions"
  echo "  invokeFunction        Invoke a Lambda fuction directly"
  echo "  updateFunctionCode    Update a Lambda functions' code"
  echo "  updateFunctionHandler Update Lambda function hanlder"
  echo "  deleteFunction        Delete a Lambda function"
  echo "  configureAppDynamicsLambda  Configure a Lambda function's AppD Environment Variables"
  echo "  createRestApi         Create an API Gateway REST API to trigger a Fuction"
  echo "  listRestApi           List all REST APIs"
  echo "  deleteRestApi         Delete an REST API"
  echo "  testRestApiCurl       Invoke the function using curl and REST API"
  echo "  testRestApiCurlError  Inject an exception into the Lambda function"
  echo "  testRestApiJavaApp    Invoke the function using the Java App"
  echo "  startJavaApp          Start the Java App as a process"
  echo "  stopJavaApp           Stop the Java App as a process"
  echo "  loadGenJavaApp        Start the Java App load generator as a process"
  echo "  installJq             Install JQ"
  echo "  installAwsCli         Install AWS CLI"
  echo "  installMaven          Install Apache Maven"
  echo "  buildLambda           Compile and package the Lambda function"
  echo "  buildJavaApp          Compile and package the Java App"
  echo "  dockerBuild           Build a Docker container, $DOCKER_IMAGE_NAME, for this lab"
  echo "  dockerRun             Run the Docker container, $DOCKER_IMAGE_NAME"
  echo "  dockerBash            Connect to Docker container, $DOCKER_IMAGE_NAME, using bash"
fi
