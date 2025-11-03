# Structured Eligibility Criteria Proof of Concept (aka sec_poc)

Proof-of-concept code to match cancer patients with clinical trials. Makes heavy use of the [NCI Thesaurus](https://ncithesaurus.nci.nih.gov/ncitbrowser/) in doing so.

This code is intended for demonstrations only; features of interest will likely be re-implemented in productionized systems such as [emFACT](https://em-fact.com/) or NCI CTS.

SEC POC consists of a PostgreSQL database populated by python ETL jobs and a UI implemented in R and [Shiny](https://shiny.posit.co/). See [etl.qmd](https://github.com/CBIIT/sec_etl/blob/main/etl.qmd) for the ETL process details.

## Set Up a Local Development Database

Install PostgreSQL. How you do this will depend on your OS and your tastes. For example, you can install it as a Docker container if you like.

To install on MacOS using [Homebrew](https://brew.sh/):

```bash
brew install postgresql@16
brew services start postgresql@16 # launches the postgres service whenever your computer launches
```

**Next, create a database and user:**

```bash
psql postgres -c "create user secapp with password 'test'"
psql postgres -c "create database sec"
psql secapp -c "grant all privileges on database sec to secapp"
```

**See [ETL](https://github.com/CBIIT/sec_etl) for instructions loading the schemas and initial data load.**

---

## Python Development

> **Note:** Python usage in this repo is limited to local scripting (e.g. ad-hoc Jupyter notebooks) and demo work located in demos/. The Python code located in db_api_etl/ is integrated with the [ETL](https://github.com/CBIIT/sec_etl) via git submodules where all the scaffolding is provided for testing/development. Eventually, the ETL code should be removed from this repo and placed in the ETL.

### Local Python Scripting

For local scripting or demo tasks in this repo, [`uv`](https://github.com/astral-sh/uv) is recommended for fast, isolated Python dependency management.

**Install dependencies including those listing in workspaces:**

```bash
uv sync --all-packages
```

**Add packages with:**

```bash
uv add # adds at the root level
uv add --package <workspace name> # adds to a specific workspace (e.g. an isolated project listed in demos/)
```

**Export requirements for a specific workspace:**

```bash
uv export --format requirements.txt --package <workspace name>
```

## R Development

This project uses **R 4.5.1** and [renv](https://rstudio.github.io/renv/) for dependency management.

### Getting Started

#### Installing R

- **Install R 4.5.1** if you do not already have it. You can download it from [CRAN](https://cran.r-project.org/).
- Or using Docker,

```bash
workspace_name=sec_poc_workspace
mkdir $workspace_name
cd $workspace_name
git clone https://github.com/CBIIT/sec_poc.git # this repo; a dashboard for querying CTS API trials using enhanced criteria
git clone https://github.com/CBIIT/sec_admin.git # the admin dashboard for reviewing NLP generated criteria expressions
git clone https://github.com/CBIIT/sec_etl.git # the ETL process that populates the database
git clone https://github.com/CBIIT/sec_nlp.git # the NLP logic that integrates with the ETL
docker run -it -d -v "/Users/$(whoami)/${workspace_name}:/app" --name sec_poc_workspace-4.5.1 rocker/r-ver:4.5.1 sleep infinity
```

- Attach to the container using [VS Code Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers) or similar. Alternatively, connect using `docker exec -it sec_poc_workspace-4.5.1 bash`. This docker container will have the workspace directory mounted to synchronize any code changes between the container and host. I prefer opening each repo in a separate VS Code workspace by first launching the container in VS Code and then running `code -n {name of cloned repo}`.

#### Installing R Dependencies

2. **Initialize the renv environment:**

   - Open a terminal in the project directory and start R:
     ```R
     # In the R console
     renv::restore()
     ```
   - This will install all required R packages as specified in `renv.lock`.

3. **Set up environment variables:**

   - Before running the app, you must set environment variables referenced in [`config.yml`](config.yml):
     - Obtain a working example of required environment variables from AWS Account `NIH.NCI.CBIIT.FHIR.NONPROD` and `s3://sec-poc-archive/.env.local`.
       - To access, submit an NCI ServiceNow ticket requesting poweruser access to `NIH.NCI.CBIIT.FHIR.NONPROD`.
     - The database variables will depend on your approach to [Set up a Local Development Database](#set-up-a-local-development-database).
     - Add a valid CTS API key. A key is provided for you in the `s3://sec-poc-archive/.env.local` (dev) and `s3://sec-poc-archive/.env` (prod) files, but you can also create your own by following the instructions in the [NCI CTS API documentation](https://clinicaltrialsapi.cancer.gov/doc). Note that the key provided in S3 has a higher rate limit, which is ideal for production use.

4. **Run the app:**
   - You can run `app.R` from RStudio or from the command line using:
     ```bash
     Rscript app.R
     # or
     R -e "shiny::runApp()"
     ```

#### Notes

- The R packages needed are managed by `renv` and listed in `renv.lock`. If you need to add or update packages, use `renv::install()` and then run `renv::snapshot()` to update the lockfile.

## Production Deployment

This application is deployed on the NCI's internal Appshare (Posit Connect) using [Posit Publisher](https://github.com/posit-dev/publisher). There are other ways to deploy which are documented on [publishing overview](https://docs.posit.co/connect/user/publishing-overview/). They will be similar to process outlined here.

> **NOTE:** The NCI's Appshare (Posit Connect) located at https://appshare-dev.cancer.gov/ is treated as a Dev environment, which means it doesn't run 24x7 and has fewer system resources; it shuts down around 5-6pm ET daily. For this reason, the ETL deployment is hosted on a separate instance of Posit Connect, but it's still under the NCI's infrastructure. It is located at https://posit-connect-prod.cancer.gov/.

### 1. Prerequisites

- All operations involving the NCI's Appshare (Posit Connect) located at https://appshare-dev.cancer.gov/ require NIH VPN connection.
- Ensure you have publisher access to the Posit Connect server: https://appshare-dev.cancer.gov/ (contact one of the administrators for publisher access: George Zaki, Guillermo Choy-Leon, Raymond Kobe)
- Create an API key under your profile inside of Appshare (Posit Connect). Reference https://docs.posit.co/connect/user/api-keys/.

### 2. Prepare Your Project

The project is already prepared and the configuration/deployment files are located under .posit/. Refer to those deployment files for adding/removing application files or environment variables. To create a new deployment, see the [vscode instructions](https://github.com/posit-dev/publisher/blob/main/docs/vscode.md).

> **Note:** For more configuration options, see the [Posit Publisher configuration reference](https://github.com/posit-dev/publisher/blob/main/docs/configuration.md).

### 3. Deploy

See the [vscode instructions](https://github.com/posit-dev/publisher/blob/main/docs/vscode.md) for help with deploying the project.

### 4. Post-Deployment

- After deployment, access your app at the provided URL on https://appshare-dev.cancer.gov/.
- If you need to update your app, repeat the deploy step after making changes.

**Best Practices:**

- Do not store secrets in the repo files. Instead, use the Posit Connect UI to set environment variables securely. Once they are set, they cannot be revealed, so be sure to have a secure copy available elsewhere.
