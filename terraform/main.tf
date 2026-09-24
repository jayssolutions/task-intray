module "network" {
  source       = "./modules/network"
  project_name = var.project_name
  vpc_cidr     = var.vpc_cidr
}

module "alb" {
  source            = "./modules/alb"
  project_name      = var.project_name
  vpc_id            = module.network.vpc_id
  public_subnet_ids = module.network.public_subnet_ids
}

module "compute" {
  source             = "./modules/compute"
  project_name       = var.project_name
  vpc_id             = module.network.vpc_id
  public_subnet_ids  = module.network.public_subnet_ids
  alb_security_group = module.alb.alb_security_group_id
  target_group_arn   = module.alb.target_group_arn
  instance_type      = var.instance_type
  instance_count     = var.instance_count
  admin_cidr         = var.admin_cidr
  monitoring_cidrs   = var.monitoring_cidrs
  public_key         = var.public_key

  monitoring_security_group_id = var.enable_monitoring ? module.monitoring[0].security_group_id : null
}

module "monitoring" {
  source        = "./modules/monitoring"
  count         = var.enable_monitoring ? 1 : 0
  project_name  = var.project_name
  vpc_id        = module.network.vpc_id
  subnet_id     = module.network.public_subnet_ids[0]
  key_name      = module.compute.key_name
  admin_cidr    = var.admin_cidr
  instance_type = var.prometheus_instance_type
}
