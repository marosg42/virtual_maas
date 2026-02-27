output "juju_snap_version" {
  description = "Installed Juju version string (e.g. 4.0.3-ubuntu-amd64)"
  value       = data.external.juju_version_info.result.snap_version
}

output "juju_major_version" {
  description = "Juju major version number (3 or 4)"
  value       = data.external.juju_version_info.result.major
}
