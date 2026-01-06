# Quick Docker Build for R and PG Containers

 * The files here are for building the R and PG containers quickly using prebuilt images instead of building. As of this writing, this works fine.
 * This was created because:
   * Problems were encountered with the build (in oel8 folder)
   * It takes a very long time to debug given the long build time
   * The prebuilt image works
   * I wanted to use latest R packages

## The Files in this Folder
 * docker-compose.yaml  -- the same as oel8 version except for using a dot env (.env) file
 * Dockerfile -- mostly installs images from remote repo
 * create_r_package_installer.py -- Does the following:
   * gets the packages in files/install_deps.pak.R and gets the latest version for each from remote repo
   * outputs files/quick-install-r-packages.R which is called with RUN Rscript "quick-install-r-packages.R"
   * when quick-install-r-packages.R runs, it installs the images instead of building
 * .env - this file is not checked in. It should be created. This is mine, yours will be different
 ```.dotenv
   SEC_POC_HOME=$HOME/p/sec/sec_etl/sec_poc   --- points to my sec_poc folder
   PG_EXTERNAL_PORT=5433                      --- my PG port
   LOCAL_PG_DATA_DIR=$HOME/p/sec/sec_etl/sec_poc/postgres_data_dir --- not sure this is needed but it is the local location of the container's pg data dir
```

## Other Related Files
 * build-r-n-pg.sh -- does the build
 * run-r-n-pg.sh   -- runs the container
 * files/CMakeLists.txt -- used to cmake abseil package. TBD May not be needed as mostly using prebuilt images
 * files/quick-install-r-packages.R -- installs R images of packages whose names are in install_deps.pak.R
 * files/init.sql -- gets copied to /docker-entrypoint-initdb.d/ in postgres container and runs on startup
 * init.sh -- currently empty script but runs at the end of the R container build and intended for additional tasks.
 
## Issues with oel8 Docker Build
 * For some unknown reason, the docker build was failing on abseil package which is a dependency of one of the listed packages.
 * I had to compile abseil package and this required changes to the Dockerfile.
 * Additional build problems were encountered and these always occurred near the end of the build at 60+ minutes.
