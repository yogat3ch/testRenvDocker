# ARG allows you to define a build-time variable that can be used in subsequent instructions in the Dockerfile.
# Here, it sets the default architecture to arm64, but this can be overridden during build if needed.
ARG ARCH=arm64

# This sets up a base image for the amd64 architecture using a specific version of rocker/r-ver,
# a Docker image for R based on Debian. The SHA256 digest ensures the image is exactly the version expected.
FROM rocker/r-ver:4.3@sha256:48f469c383d1e90fe09c208c6e2bb2f251bca6b72fefdb0ce2e483e4a292f974 AS base-amd64

# This sets up a base image for the arm64 architecture, similar to the amd64, but for ARM processors.
FROM rocker/r-ver:4.3.0@sha256:9c1703e265fca5a17963a1b255b3b2ead6dfc6d65c57e4af2f31bec15554da86 AS base-arm64

# This stage selects the base image based on the ARCH argument provided at build time.
# It effectively chooses the right base image for the target architecture.
FROM base-${ARCH}

# Begins the installation of system dependencies.
# - `apt-get update` updates the list of available packages and their versions,
#   but it does not install or upgrade any packages.
# - `apt-get install` installs the listed packages and their dependencies.
# Each line lists a package and its version to ensure consistency and predictability in the environment.
RUN apt-get update -y && apt-get install -y \
    libmysqlclient-dev \
    libcurl4-openssl-dev \
    libssl-dev \
    make \
    zlib1g-dev\
    git \
    libicu-dev \
    libfreetype6-dev \
    libfribidi-dev \
    libharfbuzz-dev \
    libxml2-dev \
    libxt6 \
    libfontconfig1-dev \
    libjpeg-dev \
    libpng-dev \
    libtiff-dev \
    pandoc \
    libgit2-dev \
    && rm -rf /var/lib/apt/lists/* # Removes the package lists to keep the image size down.

# Creates a directory for R's internal configuration files.
# This ensures that R has all necessary directories for system-level configuration,
# which can sometimes be crucial for package installation and management.
RUN mkdir -p /usr/lib/R/etc/

# Configures global R environment settings.
# These settings include enabling 'pak' for faster package installation,
# setting a CRAN mirror for consistent package retrieval,
# specifying the download method, and setting the number of cores for parallel operations.
RUN echo "options(renv.config.pak.enabled = TRUE, repos = c(CRAN = 'https://cran.rstudio.com/'), download.file.method = 'libcurl', Ncpus = parallel::detectCores())" | tee /usr/local/lib/R/etc/Rprofile.site | tee /usr/lib/R/etc/Rprofile.site

# Creates the working directory inside the container where the application code will reside.
RUN mkdir ./testRenvDocker

# Sets the working directory to /dmdu.
# All subsequent instructions in the Dockerfile will operate within this directory.
WORKDIR ./testRenvDocker

# Copies the renv.lock file from your local project into the Docker image.
# This lock file ensures that R packages are installed at specific versions for reproducibility.
COPY renv.lock renv.lock

# Copies the .Rbuildignore file into the Docker image.
# This file indicates which files and directories should be ignored by R build tools.
COPY .Rbuildignore .Rbuildignore

# Copies the 'renv' directory, which contains R package caches and configuration files.
# This directory helps 'renv' manage packages more efficiently.
COPY renv renv

# Sets the RENV_PATHS_LIBRARY environment variable.
# This tells 'renv' where to store and look for installed R packages.
ENV RENV_PATHS_LIBRARY /usr/local/lib/R/site-library

# Installs the 'renv' package, a package management tool that helps isolate project-specific dependencies.
RUN R --quiet -e "install.packages('renv')"

# Installs the 'remotes' package, which is useful for installing R packages from sources such as GitHub.
RUN R --quiet -e "install.packages('remotes')"

# Restores the R environment based on the renv.lock file.
# This ensures that all R package dependencies are installed at the correct versions.
RUN R --quiet -e "renv::diagnostics();renv::restore(library = '/usr/local/lib/R/site-library')"