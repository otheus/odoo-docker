# DAP project

## Docker installation (generic)

### Components

* Odoo Version 18.0 
  - Dockerfile available from https://github.com/odoo/docker.git
  - In that repository is a directory for versions 17, 18, and 19. 
  - The Dockerfile install version-specific and Ubuntu-specific 
    packages for odoo from 
	http://apt.postgresql.org/pub/repos/apt/
  - The Dockerfile also installs supporting packages for python

* Add-on: `rest_api_odoo`
  - from https://apps.odoo.com/apps/modules/18.0/rest_api_odoo
  - This must be manually downloaded as a ZIP file. 
  - I could find no way to download this automatically. 
  - The web-site implements some kind of anti-bot guard
    which prevents pure curl from retrieving it. 
    Thus, it is included in the same dir as the Dockerfile

* Add-on: `gd_at`
  - From https://developer.rad.local/DefaultCollection/GD_AT/_git/GD_AT_ODOO_PLUGIN_GIT
  - Version with short-hash 17e7981c is used. Last commit was 15. Dez 2025
  - Downloaded as ZIP and must be in same file as Dockerfile

* Postgresql
  - Seemingly version agnostic, but probably 12+ 
  - postgres:18.3-alpine3.23 is used here.

### Installation steps

1. Clone the odoo-docker repository
2. Create a branch in the repository so that changes are not pushed upstream
   (and hopefully separate repository when that becomes possible for me via ssh)
3. Change directory to 18.0
4. Modify the Dockerfile (SEE SEPARATE SECTION, BELOW)
5. Download the rest\_api\_odoo as a zip file and place in the 18.0 directory
6. Download the gd\_at as a zip file from the latest commit. Use the short-hash as the
   identifier in the name. 
7. Pull postgresql image. 
8. Create a network "odoo-net" (this is required on MacOS, maybe not others)

        docker network create odoo-net

9. Create a running postgresql server on this network, with TRUST credentials:

        docker run  -d -e POSTGRES_HOST_AUTH_METHOD=trust --name pgdb --network odoo-net -p 5432:5432 postgres:18.3-alpine3.23 
       
   This exposes the postgresql service to the localhost on port 5432. 
   Note: possibly dangerous or needing modification for your environment
10. Create the database user and database to be owned by that user:

        PGDBPASS=$(head -c 12 /dev/random | base64 | tr =+/ % )
        psql -h localhost -U postgres -c 'create user "dap" with password $$'"$PGDBPASS"'$$'

    Because "trust" is used above, the actual password is irrelevant. But this is a Good Practice(tm).

        psql -h localhost -U postgres -c 'create database dap owner dap;'

    [!NOTE]: The database name MUST match the owner name. This requirement seems to be a design flaw in odoo. 

12. Build the docker image:

        IMGNAME=dag-odoo:18.0_ub2404_$( date +%F_%H%M ); docker build -t $IMGNAME

12. Create a new container in the background using the newly built image

        docker run -d --name odoo --network odoo-net -p 8069:8069 \
          -e HOST=pgdb -e USER=dap -e PASSWORD=$PGDBPASS "$IMGNAME" -- \
          -i base -u all 

    [!WARNING]: This method is insecure: the password is exposed to other processes on the same host
    (same pid-namespace or host's pid-namespace). `env_file` must be used. Inluding passwords within 
    a container is also considered dangerous, without the use of a "vault" mapping. 

    The additional options (`-i base -u all` are needed at least on **THE FIRST RUN** 
    in order to initialize the database and modules. <I think!?!>

13. Connect to the service on via the browser localhost:8069, use "admin" and "admin" for the username and password.


### Dockerfile modifications

1. Use Ubuntu:2404-long-term-support for a stable base system. 

        FROM ubuntu:24.04

2. Install unzip via a RUN command. This could be done at an earlier step

        RUN set -e ;\
            apt-get update ;\
            apt-get -y install --no-install-recommends unzip

3. Move the creation of the /mnt/extra-addons to its own RUN command.
        
4. Add the plugin files to /tmp and unzip them into /mnt/extra-addons.
   These must be placed between the `RUN ..mkdir /mnt/extra-addons` line above,
   and before the `VOLUME ["/var/lib/odoo", "/mnt/extra-addons"]`

        ADD rest_api_odoo-17.0.1.0.1.zip /tmp/rest_api_odoo.zip
        ADD gd_at-17e7981c.zip /tmp/gd_at.zip

        RUN set -e ;\
            cd /mnt/extra-addons ;\
            umask 0022 ;\
            unzip /tmp/rest_api_odoo.zip ;\
            unzip /tmp/gd_at.zip ;\
            rm -f /tmp/*.zip


5. Add special configuration line: `server_wide_modules`:

        # Needed for Special modules
        RUN tee -a /etc/odoo/odoo.conf <<-EOF
                server_wide_modules = web, base, rest_api_odoo
                EOF


### Errors after ativation of GD:

This appears in a pop-up window after hitting the "Activate" button:

```
Traceback (most recent call last):
File "/usr/lib/python3/dist-packages/odoo/modules/loading.py", line 90, in load_demo load_data(env(su=True), idref, mode, kind='demo', package=package)
File "/usr/lib/python3/dist-packages/odoo/modules/loading.py", line 72, in load_data tools.convert_file(env, package.name, filename, idref, mode, noupdate, kind)
File "/usr/lib/python3/dist-packages/odoo/tools/convert.py", line 662, in convert_file convert_xml_import(env, module, fp, idref, mode, noupdate)
File "/usr/lib/python3/dist-packages/odoo/tools/convert.py", line 712, in convert_xml_import doc = etree.parse(xmlfile) ^^^^^^^^^^^^^^^^^^^^
File "src/lxml/etree.pyx", line 3570, in lxml.etree.parse
File "src/lxml/parser.pxi", line 1973, in lxml.etree._parseDocument
File "src/lxml/parser.pxi", line 1993, in lxml.etree._parseFilelikeDocument
File "src/lxml/parser.pxi", line 1887, in lxml.etree._parseDocFromFilelike
File "src/lxml/parser.pxi", line 1224, in lxml.etree._BaseParser._parseDocFromFilelike
File "src/lxml/parser.pxi", line 633, in lxml.etree._ParserContext._handleParseResultDoc
File "src/lxml/parser.pxi", line 743, in lxml.etree._handleParseResult
File "src/lxml/parser.pxi", line 672, in lxml.etree._raiseParseError
File "/mnt/extra-addons/gd_at/demo/demo.xml", line 2 lxml.etree.XMLSyntaxError: Start tag expected, '<' not found, line 2, column 1
```
