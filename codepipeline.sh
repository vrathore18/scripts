

pipelineid=$( aws codepipeline start-pipeline-execution --name test --region us-east-1 --query 'pipelineExecutionId' --output text)
echo $pipelineid
function getlogs {
	deploy_id=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Deploy` && latestExecution.pipelineExecutionId==`'${pipelineid}'`].actionStates[0].latestExecution.externalExecutionId' --output text)
	echo $deploy_id
	groupName=$(aws codebuild batch-get-builds --ids ${deploy_id} --region us-east-1 --query 'builds[0].logs.groupName' --output text)
	streamName=$(aws codebuild batch-get-builds --ids ${deploy_id} --region us-east-1 --query 'builds[0].logs.streamName' --output text)
	echo $groupName
	echo $streamName
	aws logs get-log-events  --log-group-name ${groupName}  --log-stream-name ${streamName} --region us-east-1 | jq ".events[].message"

}

# Checkouts
lastpipelineExecutionId_checkout=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Source`].latestExecution.pipelineExecutionId' --output text)
echo $lastpipelineExecutionId_checkout
while [[ "${pipelineid}" != "${lastpipelineExecutionId_checkout}" ]]; do 
	sleep 10
	lastpipelineExecutionId_checkout=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Source`].latestExecution.pipelineExecutionId' --output text)
	echo $lastpipelineExecutionId_checkout
done
build_status_checkout=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Source` && latestExecution.pipelineExecutionId==`'${pipelineid}'`].latestExecution.status' --output text)
echo $build_status_checkout
while [[ "${build_status_checkout}" == "InProgress" ]]; do 
	sleep 10
	build_status_checkout=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Source` && latestExecution.pipelineExecutionId==`'${pipelineid}'`].latestExecution.status' --output text)
	echo $build_status_checkout
done
if [ "${build_status_checkout}" != "Succeeded" ] ; then
	echo "Checkout Failed"
	exit 1
elif [ "${build_status_checkout}" = "Succeeded" ]; then
	echo "Checkout Completed"
fi

#Codebuild
lastpipelineExecutionId=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Build`].latestExecution.pipelineExecutionId' --output text)
echo $lastpipelineExecutionId
while [[ "${pipelineid}" != "${lastpipelineExecutionId}" ]]; do 
	sleep 10
	lastpipelineExecutionId=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Build`].latestExecution.pipelineExecutionId' --output text)
	echo $lastpipelineExecutionId
done
build_status=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Build` && latestExecution.pipelineExecutionId==`'${pipelineid}'`].latestExecution.status' --output text)
echo $build_status
while [[ "${build_status}" == "InProgress" ]]; do 
	sleep 20
	build_status=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Build` && latestExecution.pipelineExecutionId==`'${pipelineid}'`].latestExecution.status' --output text)
	echo "Codebuild is "$build_status
done
if [ "${build_status}" != "Succeeded" ] ; then
	getlogs
	exit 1
elif [ "${build_status}" = "Succeeded" ]; then
	echo "Build Completed"
	getlogs
fi

#Codedeploy
lastpipelineExecutionId_deploy=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Deploy`].latestExecution.pipelineExecutionId' --output text)
echo $lastpipelineExecutionId_deploy
while [[ "${pipelineid}" != "${lastpipelineExecutionId_deploy}" ]]; do 
	sleep 10
	lastpipelineExecutionId_deploy=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Deploy`].latestExecution.pipelineExecutionId' --output text)
	echo $lastpipelineExecutionId_deploy
done
deploy_status=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Deploy` && latestExecution.pipelineExecutionId==`'${pipelineid}'`].latestExecution.status' --output text)
echo $deploy_status
while [[ "${deploy_status}" == "InProgress" ]]; do 
	sleep 20
	deploy_status=$(aws codepipeline get-pipeline-state --region us-east-1 --name test --query 'stageStates[?stageName==`Deploy` && latestExecution.pipelineExecutionId==`'${pipelineid}'`].latestExecution.status' --output text)
	echo "Codedeploy is "$deploy_status
done
if [ "${deploy_status}" != "Succeeded" ] ; then
	getlogs
	exit 1
elif [ "${deploy_status}" = "Succeeded" ]; then
	echo "Deploy Completed"
	getlogs

fi
