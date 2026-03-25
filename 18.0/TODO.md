# Docker installation of odoo

## Problems with Dockerfile 

[!NOTE]: as of commit b5ff5c6057cc03edb758a571e776914ed56def8f

- The Dockerfile relies on a more recent version of Ubuntu
- The Dockerfile installs supporting packages for python, without specifying versions
- The entrypoint file is rather non-standard 
- Some anti-patterns are used (not using base image, using a non-LXC compliant SHELL 
  command).
- The container / entrypoint relies on a database that has a db-superuser and a static
  db-password. This is inherently bad. 

## TODO

- [ ] Use Ubuntu:2404-long-term-support for a stable base system. Even better is Alpine, but
      it is unclear what else depends on it.

- [ ] Create directories using the "install" command for directories, to set permissions and owners

- [ ] For new installation: entrypoint should generate a random password for the admin account

