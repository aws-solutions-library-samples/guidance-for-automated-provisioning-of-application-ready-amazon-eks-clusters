module "kokoro_tts_ci" {
  count  = 0#lookup(var.cluster_config.capabilities, "inference", false) ? 1 : 0
  source = "./ci/kokoro-tts"

  github_repo_url = var.github_repo_url
  region          = var.region
  environment     = var.environment

  tags = merge(
    var.tags,
    {
      "Environment" = var.environment
      "Project"     = "KokoroTTS"
    }
  )
} 