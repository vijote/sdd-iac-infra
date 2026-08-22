# Terraform Lint Configuration
# Enforces best practices and consistency for VPC Networking Foundation module

config {
  module = true
  force = false
  call_module_type = "all"
}

# Rules for Terraform language best practices
rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_documented_outputs" {
  enabled = true
}

rule "terraform_documented_variables" {
  enabled = true
}

rule "terraform_empty_list_equality" {
  enabled = true
}

rule "terraform_env_var_quotes" {
  enabled = false  # Allow flexibility in environment variable usage
}

rule "terraform_escape_quotation_mark" {
  enabled = true
}

rule "terraform_file_mode_not_executable" {
  enabled = true
}

rule "terraform_format_strings" {
  enabled = true
}

rule "terraform_invalid_column" {
  enabled = true
}

rule "terraform_module_call_declared_vars" {
  enabled = true
}

rule "terraform_module_pinned_source" {
  enabled = false  # Allow local modules for development
}

rule "terraform_module_version" {
  enabled = false  # Version constraints handled in versions.tf
}

rule "terraform_naming_convention" {
  enabled = true
  format = "snake_case"
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_required_version" {
  enabled = true
}

rule "terraform_standard_library" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}

rule "terraform_unused_variables" {
  enabled = true
}

rule "terraform_workspace_invalid" {
  enabled = true
}

# AWS-specific rules for VPC networking
rule "aws_acm_certificate_invalid_certificate" {
  enabled = true
}

rule "aws_acm_certificate_invalid_certificate_chain" {
  enabled = true
}

rule "aws_acm_certificate_invalid_private_key" {
  enabled = true
}

rule "aws_alb_invalid_load_balancer" {
  enabled = true
}

rule "aws_alb_invalid_target_group" {
  enabled = true
}

rule "aws_api_gateway_invalid_account_configuration" {
  enabled = true
}

rule "aws_api_gateway_invalid_api_key" {
  enabled = true
}

rule "aws_api_gateway_invalid_authorizer" {
  enabled = true
}

rule "aws_api_gateway_invalid_base_path_mapping" {
  enabled = true
}

rule "aws_api_gateway_invalid_deployment" {
  enabled = true
}

rule "aws_api_gateway_invalid_domain_name" {
  enabled = true
}

rule "aws_api_gateway_invalid_integration" {
  enabled = true
}

rule "aws_api_gateway_invalid_integration_response" {
  enabled = true
}

rule "aws_api_gateway_invalid_method" {
  enabled = true
}

rule "aws_api_gateway_invalid_method_response" {
  enabled = true
}

rule "aws_api_gateway_invalid_model" {
  enabled = true
}

rule "aws_api_gateway_invalid_request_validator" {
  enabled = true
}

rule "aws_api_gateway_invalid_resource" {
  enabled = true
}

rule "aws_api_gateway_invalid_rest_api" {
  enabled = true
}

rule "aws_api_gateway_invalid_stage" {
  enabled = true
}

rule "aws_api_gateway_invalid_usage_plan" {
  enabled = true
}

rule "aws_api_gateway_invalid_vpc_link" {
  enabled = true
}

rule "aws_athena_invalid_named_query" {
  enabled = true
}

rule "aws_autoscaling_group_invalid_desired_capacity" {
  enabled = true
}

rule "aws_autoscaling_group_invalid_max_size" {
  enabled = true
}

rule "aws_autoscaling_group_invalid_min_size" {
  enabled = true
}

rule "aws_cloudformation_stack_invalid_notification_arn" {
  enabled = true
}

rule "aws_cloudformation_stack_invalid_template_parameter" {
  enabled = true
}

rule "aws_cloudformation_stack_invalid_timeout_in_minutes" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_cookie_preference" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_forwarded_values" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_geographic_restriction" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_lambda_function_association" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_logging_config" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_origin" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_origin_group" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_origin_access_identity" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_price_class" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_restrictions" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_s3_origin_config" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_trusted_signer" {
  enabled = true
}

rule "aws_cloudfront_distribution_invalid_viewer_certificate" {
  enabled = true
}

rule "aws_cloudtrail_invalid_data_resource" {
  enabled = true
}

rule "aws_cloudtrail_invalid_event_selector" {
  enabled = true
}

rule "aws_cloudtrail_invalid_kms_key_id" {
  enabled = true
}

rule "aws_cloudwatch_event_rule_invalid_event_pattern" {
  enabled = true
}

rule "aws_cloudwatch_event_rule_invalid_target" {
  enabled = true
}

rule "aws_cloudwatch_log_group_invalid_retention_in_days" {
  enabled = true
}

rule "aws_cloudwatch_log_metric_filter_invalid_metric_transformation" {
  enabled = true
}

rule "aws_codebuild_project_invalid_cache" {
  enabled = true
}

rule "aws_codebuild_project_invalid_environment" {
  enabled = true
}

rule "aws_codebuild_project_invalid_source" {
  enabled = true
}

rule "aws_codepipeline_invalid_artifact_store" {
  enabled = true
}

rule "aws_codepipeline_invalid_stage" {
  enabled = true
}

rule "aws_cognito_identity_pool_invalid_identity_pool" {
  enabled = true
}

rule "aws_cognito_identity_pool_invalid_role_mapping" {
  enabled = true
}

rule "aws_cognito_user_pool_client_invalid_client" {
  enabled = true
}

rule "aws_cognito_user_pool_invalid_user_pool" {
  enabled = true
}

rule "aws_config_aggregate_authorization_invalid_account_id" {
  enabled = true
}

rule "aws_config_configuration_aggregator_invalid_account_aggregation_source" {
  enabled = true
}

rule "aws_config_configuration_aggregator_invalid_organization_aggregation_source" {
  enabled = true
}

rule "aws_config_configuration_recorder_invalid_recording_group" {
  enabled = true
}

rule "aws_config_delivery_channel_invalid_s3_bucket_name" {
  enabled = true
}

rule "aws_config_rule_invalid_source" {
  enabled = true
}

rule "aws_datapipeline_pipeline_invalid_parameter_object" {
  enabled = true
}

rule "aws_datapipeline_pipeline_invalid_pipeline" {
  enabled = true
}

rule "aws_dax_cluster_invalid_cluster" {
  enabled = true
}

rule "aws_dax_cluster_invalid_parameter_group" {
  enabled = true
}

rule "aws_dax_subnet_group_invalid_subnet_group" {
  enabled = true
}

rule "aws_db_cluster_invalid_cluster" {
  enabled = true
}

rule "aws_db_event_subscription_invalid_subscription" {
  enabled = true
}

rule "aws_db_instance_invalid_instance" {
  enabled = true
}

rule "aws_db_option_group_invalid_option" {
  enabled = true
}

rule "aws_db_parameter_group_invalid_parameter" {
  enabled = true
}

rule "aws_db_security_group_invalid_security_group" {
  enabled = true
}

rule "aws_db_snapshot_invalid_snapshot" {
  enabled = true
}

rule "aws_db_subnet_group_invalid_subnet_group" {
  enabled = true
}

rule "aws_default_network_acl_invalid_egress" {
  enabled = true
}

rule "aws_default_network_acl_invalid_ingress" {
  enabled = true
}

rule "aws_default_route_table_invalid_route" {
  enabled = true
}

rule "aws_default_security_group_invalid_egress" {
  enabled = true
}

rule "aws_default_security_group_invalid_ingress" {
  enabled = true
}

rule "aws_directory_service_directory_invalid_directory" {
  enabled = true
}

rule "aws_dynamodb_table_invalid_attribute" {
  enabled = true
}

rule "aws_dynamodb_table_invalid_global_secondary_index" {
  enabled = true
}

rule "aws_dynamodb_table_invalid_local_secondary_index" {
  enabled = true
}

rule "aws_dynamodb_table_invalid_point_in_time_recovery" {
  enabled = true
}

rule "aws_dynamodb_table_invalid_table" {
  enabled = true
}

rule "aws_dynamodb_table_invalid_ttl" {
  enabled = true
}

rule "aws_ebs_volume_invalid_volume" {
  enabled = true
}

rule "aws_ecr_repository_invalid_repository" {
  enabled = true
}

rule "aws_ecs_cluster_invalid_cluster" {
  enabled = true
}

rule "aws_ecs_service_invalid_service" {
  enabled = true
}

rule "aws_ecs_task_definition_invalid_container_definition" {
  enabled = true
}

rule "aws_ecs_task_definition_invalid_task_definition" {
  enabled = true
}

rule "aws_efs_file_system_invalid_file_system" {
  enabled = true
}

rule "aws_efs_mount_target_invalid_mount_target" {
  enabled = true
}

rule "aws_eks_cluster_invalid_cluster" {
  enabled = true
}

rule "aws_eks_node_group_invalid_node_group" {
  enabled = true
}

rule "aws_elastic_beanstalk_application_invalid_application" {
  enabled = true
}

rule "aws_elastic_beanstalk_application_version_invalid_application_version" {
  enabled = true
}

rule "aws_elastic_beanstalk_environment_invalid_environment" {
  enabled = true
}

rule "aws_elasticache_cluster_invalid_cluster" {
  enabled = true
}

rule "aws_elasticache_parameter_group_invalid_parameter" {
  enabled = true
}

rule "aws_elasticache_replication_group_invalid_replication_group" {
  enabled = true
}

rule "aws_elasticache_subnet_group_invalid_subnet_group" {
  enabled = true
}

rule "aws_elasticsearch_domain_invalid_domain" {
  enabled = true
}

rule "aws_elb_invalid_load_balancer" {
  enabled = true
}

rule "aws_emr_cluster_invalid_bootstrap_action" {
  enabled = true
}

rule "aws_emr_cluster_invalid_cluster" {
  enabled = true
}

rule "aws_emr_cluster_invalid_instance_fleet" {
  enabled = true
}

rule "aws_emr_cluster_invalid_instance_group" {
  enabled = true
}

rule "aws_emr_cluster_invalid_step" {
  enabled = true
}

rule "aws_flow_log_invalid_log_destination" {
  enabled = true
}

rule "aws_fsx_lustre_file_system_invalid_file_system" {
  enabled = true
}

rule "aws_fsx_windows_file_system_invalid_file_system" {
  enabled = true
}

rule "aws_glacier_vault_invalid_vault" {
  enabled = true
}

rule "aws_glue_catalog_database_invalid_database" {
  enabled = true
}

rule "aws_glue_catalog_table_invalid_table" {
  enabled = true
}

rule "aws_glue_crawler_invalid_crawler" {
  enabled = true
}

rule "aws_glue_job_invalid_job" {
  enabled = true
}

rule "aws_glue_trigger_invalid_action" {
  enabled = true
}

rule "aws_iam_access_key_invalid_user" {
  enabled = true
}

rule "aws_iam_group_invalid_group" {
  enabled = true
}

rule "aws_iam_group_invalid_group_membership" {
  enabled = true
}

rule "aws_iam_group_invalid_group_policy" {
  enabled = true
}

rule "aws_iam_group_invalid_group_policy_attachment" {
  enabled = true
}

rule "aws_iam_instance_profile_invalid_instance_profile" {
  enabled = true
}

rule "aws_iam_policy_invalid_policy" {
  enabled = true
}

rule "aws_iam_role_invalid_assume_role_policy" {
  enabled = true
}

rule "aws_iam_role_invalid_policy" {
  enabled = true
}

rule "aws_iam_role_invalid_role" {
  enabled = true
}

rule "aws_iam_role_invalid_role_policy" {
  enabled = true
}

rule "aws_iam_role_invalid_role_policy_attachment" {
  enabled = true
}

rule "aws_iam_user_invalid_login_profile" {
  enabled = true
}

rule "aws_iam_user_invalid_policy" {
  enabled = true
}

rule "aws_iam_user_invalid_user" {
  enabled = true
}

rule "aws_iam_user_invalid_user_policy" {
  enabled = true
}

rule "aws_iam_user_invalid_user_policy_attachment" {
  enabled = true
}

rule "aws_inspector_assessment_target_invalid_assessment_target" {
  enabled = true
}

rule "aws_inspector_assessment_template_invalid_assessment_template" {
  enabled = true
}

rule "aws_instance_invalid_ebs_block_device" {
  enabled = true
}

rule "aws_instance_invalid_instance" {
  enabled = true
}

rule "aws_instance_invalid_root_block_device" {
  enabled = true
}

rule "aws_kinesis_analytics_application_invalid_application" {
  enabled = true
}

rule "aws_kinesis_analytics_application_invalid_inputschema" {
  enabled = true
}

rule "aws_kinesis_analytics_application_invalid_reference_data_source" {
  enabled = true
}

rule "aws_kinesis_firehose_delivery_stream_invalid_extended_s3_configuration" {
  enabled = true
}

rule "aws_kinesis_firehose_delivery_stream_invalid_kinesis_stream_source_configuration" {
  enabled = true
}

rule "aws_kinesis_firehose_delivery_stream_invalid_redshift_configuration" {
  enabled = true
}

rule "aws_kinesis_firehose_delivery_stream_invalid_s3_configuration" {
  enabled = true
}

rule "aws_kinesis_firehose_delivery_stream_invalid_delivery_stream" {
  enabled = true
}

rule "aws_kinesis_stream_invalid_stream" {
  enabled = true
}

rule "aws_kms_alias_invalid_alias" {
  enabled = true
}

rule "aws_kms_key_invalid_key" {
  enabled = true
}

rule "aws_lambda_alias_invalid_alias" {
  enabled = true
}

rule "aws_lambda_event_source_mapping_invalid_event_source_mapping" {
  enabled = true
}

rule "aws_lambda_function_invalid_function" {
  enabled = true
}

rule "aws_lambda_function_invalid_environment" {
  enabled = true
}

rule "aws_lambda_function_invalid_vpc_config" {
  enabled = true
}

rule "aws_lambda_layer_version_invalid_layer_version" {
  enabled = true
}

rule "aws_launch_configuration_invalid_ebs_block_device" {
  enabled = true
}

rule "aws_launch_configuration_invalid_launch_configuration" {
  enabled = true
}

rule "aws_launch_configuration_invalid_root_block_device" {
  enabled = true
}

rule "aws_launch_template_invalid_block_device_mapping" {
  enabled = true
}

rule "aws_launch_template_invalid_credit_specification" {
  enabled = true
}

rule "aws_launch_template_invalid_iam_instance_profile" {
  enabled = true
}

rule "aws_launch_template_invalid_instance_market_options" {
  enabled = true
}

rule "aws_launch_template_invalid_launch_template" {
  enabled = true
}

rule "aws_launch_template_invalid_monitoring" {
  enabled = true
}

rule "aws_launch_template_invalid_network_interfaces" {
  enabled = true
}

rule "aws_launch_template_invalid_placement" {
  enabled = true
}

rule "aws_launch_template_invalid_tag_specification" {
  enabled = true
}

rule "aws_lb_invalid_listener" {
  enabled = true
}

rule "aws_lb_invalid_load_balancer" {
  enabled = true
}

rule "aws_lb_invalid_target_group" {
  enabled = true
}

rule "aws_lightsail_instance_invalid_instance" {
  enabled = true
}

rule "aws_lightsail_instance_invalid_blueprint" {
  enabled = true
}

rule "aws_lightsail_instance_invalid_bundle" {
  enabled = true
}

rule "aws_lightsail_instance_invalid_key_pair_name" {
  enabled = true
}

rule "aws_lightsail_instance_invalid_static_ip" {
  enabled = true
}

rule "aws_media_store_container_invalid_container" {
  enabled = true
}

rule "aws_mq_broker_invalid_broker" {
  enabled = true
}

rule "aws_mq_broker_invalid_configuration" {
  enabled = true
}

rule "aws_mq_broker_invalid_log_list" {
  enabled = true
}

rule "aws_mq_broker_invalid_user" {
  enabled = true
}

rule "aws_nat_gateway_invalid_allocation_id" {
  enabled = true
}

rule "aws_nat_gateway_invalid_connectivity_type" {
  enabled = true
}

rule "aws_nat_gateway_invalid_private_ip" {
  enabled = true
}

rule "aws_nat_gateway_invalid_subnet_id" {
  enabled = true
}

rule "aws_network_acl_invalid_egress" {
  enabled = true
}

rule "aws_network_acl_invalid_ingress" {
  enabled = true
}

rule "aws_network_interface_invalid_attachment" {
  enabled = true
}

rule "aws_network_interface_invalid_interface" {
  enabled = true
}

rule "aws_opensearch_domain_invalid_domain" {
  enabled = true
}

rule "aws_organizations_account_invalid_account" {
  enabled = true
}

rule "aws_organizations_organization_invalid_organization" {
  enabled = true
}

rule "aws_organizations_organizational_unit_invalid_organizational_unit" {
  enabled = true
}

rule "aws_organizations_policy_invalid_policy" {
  enabled = true
}

rule "aws_placement_group_invalid_placement_group" {
  enabled = true
}

rule "aws_proxy_protocol_policy_invalid_instance_ports" {
  enabled = true
}

rule "aws_rds_cluster_invalid_cluster" {
  enabled = true
}

rule "aws_rds_cluster_instance_invalid_instance" {
  enabled = true
}

rule "aws_rds_cluster_parameter_group_invalid_parameter" {
  enabled = true
}

rule "aws_redshift_cluster_invalid_cluster" {
  enabled = true
}

rule "aws_redshift_cluster_invalid_logging" {
  enabled = true
}

rule "aws_redshift_parameter_group_invalid_parameter" {
  enabled = true
}

rule "aws_redshift_subnet_group_invalid_subnet_group" {
  enabled = true
}

rule "aws_route53_delegation_set_invalid_delegation_set" {
  enabled = true
}

rule "aws_route53_health_check_invalid_health_check" {
  enabled = true
}

rule "aws_route53_record_invalid_record" {
  enabled = true
}

rule "aws_route53_zone_invalid_vpc" {
  enabled = true
}

rule "aws_route53_zone_invalid_zone" {
  enabled = true
}

rule "aws_route_invalid_route" {
  enabled = true
}

rule "aws_route_table_invalid_route" {
  enabled = true
}

rule "aws_s3_bucket_invalid_accelerate_configuration" {
  enabled = true
}

rule "aws_s3_bucket_invalid_acl" {
  enabled = true
}

rule "aws_s3_bucket_invalid_bucket" {
  enabled = true
}

rule "aws_s3_bucket_invalid_cors_rule" {
  enabled = true
}

rule "aws_s3_bucket_invalid_lifecycle_rule" {
  enabled = true
}

rule "aws_s3_bucket_invalid_logging" {
  enabled = true
}

rule "aws_s3_bucket_invalid_object" {
  enabled = true
}

rule "aws_s3_bucket_invalid_replication_configuration" {
  enabled = true
}

rule "aws_s3_bucket_invalid_server_side_encryption_configuration" {
  enabled = true
}

rule "aws_s3_bucket_invalid_versioning" {
  enabled = true
}

rule "aws_s3_bucket_invalid_website" {
  enabled = true
}

rule "aws_s3_bucket_analytics_configuration_invalid_filter" {
  enabled = true
}

rule "aws_s3_bucket_inventory_invalid_configuration" {
  enabled = true
}

rule "aws_s3_bucket_metrics_configuration_invalid_filter" {
  enabled = true
}

rule "aws_s3_bucket_notification_invalid_lambda_function" {
  enabled = true
}

rule "aws_s3_bucket_notification_invalid_queue" {
  enabled = true
}

rule "aws_s3_bucket_notification_invalid_topic" {
  enabled = true
}

rule "aws_s3_bucket_policy_invalid_policy" {
  enabled = true
}

rule "aws_sagemaker_endpoint_invalid_endpoint" {
  enabled = true
}

rule "aws_sagemaker_endpoint_configuration_invalid_production_variants" {
  enabled = true
}

rule "aws_sagemaker_model_invalid_primary_container" {
  enabled = true
}

rule "aws_sagemaker_notebook_instance_invalid_instance" {
  enabled = true
}

rule "aws_sagemaker_notebook_instance_lifecycle_configuration_invalid_code" {
  enabled = true
}

rule "aws_security_group_invalid_egress" {
  enabled = true
}

rule "aws_security_group_invalid_ingress" {
  enabled = true
}

rule "aws_security_group_invalid_security_group" {
  enabled = true
}

rule "aws_service_discovery_instance_invalid_instance" {
  enabled = true
}

rule "aws_service_discovery_service_invalid_dns_config" {
  enabled = true
}

rule "aws_service_discovery_service_invalid_health_check_config" {
  enabled = true
}

rule "aws_service_discovery_service_invalid_service" {
  enabled = true
}

rule "aws_spot_fleet_request_invalid_launch_specification" {
  enabled = true
}

rule "aws_spot_fleet_request_invalid_spot_fleet_request" {
  enabled = true
}

rule "aws_spot_instance_request_invalid_spot_instance_request" {
  enabled = true
}

rule "aws_sqs_queue_invalid_queue" {
  enabled = true
}

rule "aws_sqs_queue_invalid_redrive_policy" {
  enabled = true
}

rule "aws_ssm_association_invalid_association" {
  enabled = true
}

rule "aws_ssm_document_invalid_document" {
  enabled = true
}

rule "aws_ssm_maintenance_window_invalid_task" {
  enabled = true
}

rule "aws_ssm_parameter_invalid_parameter" {
  enabled = true
}

rule "aws_ssm_patch_baseline_invalid_patch_rule" {
  enabled = true
}

rule "aws_ssm_patch_baseline_invalid_patch_group" {
  enabled = true
}

rule "aws_ssm_patch_baseline_invalid_patch_baseline" {
  enabled = true
}

rule "aws_ssm_resource_data_sync_invalid_sync_source" {
  enabled = true
}

rule "aws_ssm_resource_data_sync_invalid_sync" {
  enabled = true
}

rule "aws_subnet_invalid_subnet" {
  enabled = true
}

rule "aws_swf_domain_invalid_domain" {
  enabled = true
}

rule "aws_transfer_server_invalid_endpoint" {
  enabled = true
}

rule "aws_transfer_server_invalid_server" {
  enabled = true
}

rule "aws_transfer_server_invalid_user" {
  enabled = true
}

rule "aws_vpc_invalid_dhcp_options" {
  enabled = true
}

rule "aws_vpc_invalid_vpc" {
  enabled = true
}

rule "aws_vpc_endpoint_invalid_route_table" {
  enabled = true
}

rule "aws_vpc_endpoint_invalid_vpc_endpoint" {
  enabled = true
}

rule "aws_vpc_peering_connection_invalid_vpc_peering_connection" {
  enabled = true
}

rule "aws_vpn_connection_invalid_vpn_connection" {
  enabled = true
}

rule "aws_vpn_gateway_invalid_vpn_gateway" {
  enabled = true
}

# Plugin-specific rules
plugin "aws" {
  enabled = true
  version = "0.21.0"
  source  = "github.com/terraform-linters/tflint-ruleset-aws"
}

plugin "terraform" {
  enabled = true
  version = "0.4.0"
  source  = "github.com/terraform-linters/tflint-ruleset-terraform"
}