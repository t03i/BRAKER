# -------------------------------------------------------------------------------------- #
#                                   Stage 1: Build Image                                 #
# -------------------------------------------------------------------------------------- #

FROM python:3.12-slim as builder

ENV DEBIAN_FRONTEND=noninteractive

# Install common build dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Common build tools
    g++ \
    zlib1g-dev \
    wget \
    git \
    autoconf \
    build-essential \
    # Dependencies for AUGUSTUS and other genomic tools
    libgsl-dev \
    libboost-all-dev \
    libsuitesparse-dev \
    liblpsolve55-dev \
    libsqlite3-dev \
    libmysql++-dev \
    libboost-iostreams-dev \
    # Dependencies for tools requiring BAM file manipulations
    libbamtools-dev \
    samtools \
    libhts-dev \
    # Dependencies for homGeneMapping and utrrnaseq
    libboost-all-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# seqstats build commands
RUN cd /opt && \
    git clone --recursive https://github.com/clwgg/seqstats && \
    cd seqstats && \
    make 

# cdbfasta build commands
RUN cd /opt && \
    git clone https://github.com/gpertea/cdbfasta.git && \
    cd cdbfasta && \
    make 

# AUGUSTUS build commands
RUN cd /opt && \
    git clone https://github.com/Gaius-Augustus/Augustus.git && \
    cd Augustus && \
    make && \
    cd scripts && \
    chmod a+x *.pl *.py

# TSEBRA build commands
RUN cd /opt && \
    git clone https://github.com/Gaius-Augustus/TSEBRA 

# MakeHub build commands
RUN cd /opt && \
    git clone https://github.com/Gaius-Augustus/MakeHub.git && \
    cd MakeHub && \
    git checkout braker3 && \
    for file in bedToBigBed genePredCheck faToTwoBit gtfToGenePred hgGcPercent ixIxx twoBitInfo wigToBigWig genePredToBed genePredToBigGenePred; do \
    wget http://hgdownload.soe.ucsc.edu/admin/exe/linux.x86_64.v369/$file; \
    chmod a+x $file; \
    done

# compleasm build commands
RUN cd /opt && \
    wget https://github.com/huangnengCSU/compleasm/releases/download/v0.2.5/compleasm-0.2.5_x64-linux.tar.bz2 && \
    tar -xvjf compleasm-0.2.5_x64-linux.tar.bz2 && \
    rm compleasm-0.2.5_x64-linux.tar.bz2

# BRAKER and GeneMark-ETP build commands
RUN cd /opt && \
    git clone https://github.com/Gaius-Augustus/BRAKER.git && \
    cd BRAKER && \
    chmod a+x scripts/*.pl && \
    chmod a+x example/*/*.sh && \
    cd example && \
    wget http://bioinf.uni-greifswald.de/augustus/datasets/RNAseq.bam

RUN cd /opt && \
    git clone https://github.com/KatharinaHoff/GeneMark-ETP.git && \
    mv GeneMark-ETP ETP && \
    chmod a+x /opt/ETP/bin/*py /opt/ETP/bin/*pl /opt/ETP/tools/*

# -------------------------------------------------------------------------------------- #
#                                  Stage 2: Runtime Image                                #
# -------------------------------------------------------------------------------------- #
FROM python:3.12-slim as cli

# Copy compiled binaries and scripts from the builder stage
COPY --from=builder /opt /opt

# Install runtime dependencies for all tools, including Perl and its dependencies for script execution
RUN apt-get update && apt-get install -y --no-install-recommends \
    gosu \
    # Dependencies for AUGUSTUS and genomic analysis tools
    libgsl-dev \
    libboost-all-dev \
    libsuitesparse-dev \
    liblpsolve55-dev \
    libsqlite3-dev \
    libmysql++-dev \
    libboost-iostreams-dev \
    # Dependencies for tools working with BAM files
    libbamtools-dev \
    # Perl and dependencies for scripts in AUGUSTUS, BRAKER, etc.
    perl \
    libdbd-mysql-perl \
    libdbi-perl \
    liblist-moreutils-perl \
    libyaml-perl \
    libhash-merge-perl \
    libparallel-forkmanager-perl \
    libscalar-util-numeric-perl \
    libclass-data-inheritable-perl \
    libexception-class-perl \
    libtest-pod-perl \
    libfile-which-perl \
    libmce-perl \
    libthread-queue-perl \
    libmath-utils-perl \
    libscalar-list-utils-perl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install Python requirements
RUN pip install --no-cache-dir biopython pandas

# Set custom entrypoint for user id modification
COPY scripts/docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]

# Set work directory and user
RUN groupadd -r abc && useradd --no-log-init -r -m -g abc abc
RUN mkdir /data && chown abc:abc /data
WORKDIR /data

# Set environment paths for the installed tools
ENV PATH=/opt/seqstats:/opt/cdbfasta:/opt/Augustus/bin:/opt/Augustus/scripts:/opt/TSEBRA/bin:/opt/MakeHub:/opt/BRAKER/scripts:/opt/ETP/bin:/opt/ETP/tools::/opt/ETP/bin/gmes/ProtHint/bin:/opt/ETP/bin/gmes:/opt/compleasm_kit:$PATH \
    AUGUSTUS_CONFIG_PATH=/data/augustus/config 

# Switch to non-root user
USER abc


# -------------------------------------------------------------------------------------- #
#                             Stage 3: Jupyter Notebook Image                            #
# -------------------------------------------------------------------------------------- #
FROM jupyter/minimal-notebook as jupyter

USER root

# Install runtime dependencies for all tools, including Perl and its dependencies for script execution
RUN apt-get update && apt-get install -y --no-install-recommends \
    # Dependencies for AUGUSTUS and genomic analysis tools
    libgsl-dev \
    libboost-all-dev \
    libsuitesparse-dev \
    liblpsolve55-dev \
    libsqlite3-dev \
    libmysql++-dev \
    libboost-iostreams-dev \
    # Dependencies for tools working with BAM files
    libbamtools-dev \
    # Perl and dependencies for scripts in AUGUSTUS, BRAKER, etc.
    perl \
    libdbd-mysql-perl \
    libdbi-perl \
    liblist-moreutils-perl \
    libyaml-perl \
    libhash-merge-perl \
    libparallel-forkmanager-perl \
    libscalar-util-numeric-perl \
    libclass-data-inheritable-perl \
    libexception-class-perl \
    libtest-pod-perl \
    libfile-which-perl \
    libmce-perl \
    libthread-queue-perl \
    libmath-utils-perl \
    libscalar-list-utils-perl \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Copy compiled binaries and scripts from the builder stage
COPY --from=builder /opt /opt

# Set environment paths for the installed tools
ENV PATH=${PATH}:/opt/seqstats:/opt/cdbfasta:/opt/Augustus/bin:/opt/Augustus/scripts:/opt/TSEBRA/bin:/opt/MakeHub

# AUGUSTUS config path environment variable
ENV AUGUSTUS_CONFIG_PATH=/opt/Augustus/config/

# Since we're working in a Jupyter environment, ensure permissions are correct
RUN fix-permissions /opt && \
    fix-permissions /home/${NB_USER}

# Switch back to the notebook user
USER ${NB_UID}

# Python package installations for the notebook environment
RUN mamba install --quiet --yes \
    biopython \
    pandas && \
    mamba clean --all -f -y && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

WORKDIR "/home/${NB_USER}"