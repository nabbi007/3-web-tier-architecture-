module "networking" {
  source = "./modules/networking"

  environment              = var.environment
  project_name             = var.project_name
  owner                    = var.owner
  vpc_cidr                 = var.vpc_cidr
  public_subnet_cidrs      = var.public_subnet_cidrs
  app_private_subnet_cidrs = var.app_private_subnet_cidrs
  db_private_subnet_cidrs  = var.db_private_subnet_cidrs
  availability_zones       = var.availability_zones
}

module "security" {
  source = "./modules/security"

  vpc_id       = module.networking.vpc_id
  vpc_cidr     = module.networking.vpc_cidr
  environment  = var.environment
  project_name = var.project_name
  owner        = var.owner
  db_port      = var.db_port
}

module "alb" {
  source = "./modules/alb"

  vpc_id            = module.networking.vpc_id
  public_subnet_ids = module.networking.public_subnet_ids
  web_alb-sg_id     = module.security.web_sg_id


  environment  = var.environment
  project_name = var.project_name
  owner        = var.owner
}

module "compute" {
  source = "./modules/compute"

  vpc_id             = module.networking.vpc_id
  private_subnet_ids = module.networking.app_private_subnet_ids
  app_sg_id          = module.security.app_sg_id
  target_group_arn   = module.alb.target_group_arn

  ami_ssm_parameter_name = var.ami_ssm_parameter_name
  instance_type          = var.instance_type


  environment  = var.environment
  project_name = var.project_name
  owner        = var.owner
}

module "database" {
  source = "./modules/database"

  vpc_id        = module.networking.vpc_id
  db_subnet_ids = module.networking.db_private_subnet_ids
  db_sg_id      = module.security.db_sg_id

  environment  = var.environment
  project_name = var.project_name
  owner        = var.owner
}
