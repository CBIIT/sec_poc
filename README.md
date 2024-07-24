# Structured Eligibility Criteria Proof of Concept (aka sec_poc)

Proof-of-concept code to match cancer patients with clinical trials. Makes heavy use of the [NCI Thesaurus](https://ncithesaurus.nci.nih.gov/ncitbrowser/) in doing so.

This code is intended for demonstrations only; features of interest will likely be re-implemented in productionized systems such as [emFACT](https://em-fact.com/) or NCI CTS.

SEC POC consists of a PostgreSQL database populated by python ETL jobs, and a UI implemented in R and [Shiny](https://shiny.posit.co/). The two primary ETL jobs are [refresh_ncit_pg.py](https://github.com/CBIIT/sec_poc/blob/master/db_api_etl/refresh_ncit_pg.py), which pulls data from the NCI Thesaurus, and [api_etl_v2.py](https://github.com/CBIIT/sec_poc/blob/master/db_api_etl/api_etl_v2.py), which pulls trial data from the [NCI CTS API](https://clinicaltrialsapi.cancer.gov/). These jobs run nightly from the shiny user's crontab on ncias-d2064-v.nci.nih.gov. The R/Shiny frontend also runs on ncias-d2064-v.nci.nih.gov.

## Python Development

### Install Python Dependencies

It's recommended that you install python dependencies in an isolated environment, especially if you work with other projects. For example, using a virtual environment:

```bash
# make a virtual environment in the current direcory called "venv"
python3 -m venv venv
source venv/bin/activate
```

You'll need to run the last line every time you launch a new shell.

Install development dependencies:

```bash
pip install -r requirements.dev.txt
```

### Set Up a Local Development Database

Install PostgreSQL. How you do this will depend on your OS and your tastes. For example, you can install it as a Docker container if you like.

To install on MacOS using [Homebrew](https://brew.sh/):

```bash
brew install postgresql@11
brew services start postgresql@11 # launches the postgres service whenever your computer launches
```

Homebrew will install the psql client (psql) under /opt/homebrew/Cellar/postgresql@11/11.20_2/bin/ ; you may want to create a symlink from here to somewhere in your path.

Next, create a database and user:

```bash
psql postgres -c "create user secapp with password 'test'"
psql postgres -c "create database sec"
psql secapp -c "grant all privileges on database sec to secapp"
```

Now load the schema:

```bash
psql -U secapp -d sec -f db_api_etl/nci_api_db.sql
```

### Load Data into Your Development Database

```bash
python3 db_api_etl/refresh_ncit_pg.py --dbname sec --host localhost --user secapp --password test --port 5432 --use_evs_api_for_pref_name
```

## R Development

In production, we are using R version 3.6.3. The current R is 4.x. While it is probably OK to develop with 4.x, be sure to test thoroughly with 3.6.3 before deploying anything. Or, upgrade R on production and test thoroughly.

It can be non-trivial to install an older R version, since the R maintainers only provide binary packages for the current version. There is an R v3.6.3 docker image in the [docker directory](https://github.com/CBIIT/sec_poc/tree/master/docker/R_3.6.3) that may be of interest here.

Edit [config.yml](config.yml) to point to your local postgres DB with the correct credentials and add a valid CTS API key. Then you should be able to run app.R from either RStudio or the command line.

The R packages needed are enumerated in [sec_poc_renv.lock](https://github.com/CBIIT/sec_poc/blob/master/sec_poc_renv.lock).

# sec_poc

In production, if the packages are out of sync with dev (master), it can lead to difficult issues to debug. The [installed.packages](installed.packages) files are meant to help with resolving package version updates. When updating in production (really just reinstalling a newer version with `install.packages('package')`), R may complain about `ERROR: 'configure' exists but is not executable -- see the 'R Installation and Administration Manual'`. The source code is installed to some /tmp/dir/ before it can be compiled. Unfortunately once the gz file is extracted and ready for compile, the owner is set to `users` and the root user cannot execute. [Please see this article for explanation](https://vsoch.github.io/2013/install-r-packages-that-require-compilation-on-linux-without-sudo/). Essentially the source code needs to be installed in a folder that the root user has full exec access to. Setting the TMPDIR environment variable before executing the R install is what fixes the issue
