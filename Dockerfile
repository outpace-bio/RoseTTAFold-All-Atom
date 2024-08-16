FROM nvidia/cuda:11.8.0-cudnn8-devel-ubuntu22.04

ENV NVIDIA_VISIBLE_DEVICES all
ENV NVIDIA_DRIVER_CAPABILITIES compute,utility
ENV TORCH_CUDA_ARCH_LIST "70;75;86;89"
ENV DEBIAN_FRONTEND=noninteractive

## install wget, git, and other dependencies
RUN apt-get update && apt-get install -y wget \
    libxml2 \
    cuda-minimal-build-11-8 \
    libcusparse-dev-11-8 \
    libcublas-dev-11-8 \
    libcusolver-dev-11-8 \
    cuda-toolkit-11.8 \
    git 

RUN wget "https://github.com/conda-forge/miniforge/releases/download/23.11.0-0/Miniforge3-Linux-x86_64.sh" \ 
    && bash Miniforge3-Linux-x86_64.sh -b -p /opt/conda \
    && rm Miniforge3-Linux-x86_64.sh
ENV PATH /opt/conda/bin:$PATH
ENV CONDA_PREFIX /opt/conda

COPY environment.yaml /opt/RoseTTAFold-AA/environment.yaml
WORKDIR /opt/RoseTTAFold-AA

RUN mamba env update -n base --file environment.yaml && mamba clean --all 

## Copy over the package
## Install SE3Transformer
COPY rf2aa /opt/RoseTTAFold-AA/rf2aa
RUN pip install --no-cache-dir -r rf2aa/SE3Transformer/requirements.txt
RUN pip install rf2aa/SE3Transformer

## Install dependencies
COPY install_dependencies.sh /opt/RoseTTAFold-AA/install_dependencies.sh
RUN bash install_dependencies.sh && rm install_dependencies.sh

## Install BLAST
RUN wget https://ftp.ncbi.nlm.nih.gov/blast/executables/legacy.NOTSUPPORTED/2.2.26/blast-2.2.26-x64-linux.tar.gz \
    && mkdir -p blast-2.2.26 \
    && tar -xf blast-2.2.26-x64-linux.tar.gz -C blast-2.2.26 \
    && cp -r blast-2.2.26/blast-2.2.26/ blast-2.2.26_bk \
    && rm -r blast-2.2.26 \
    && mv blast-2.2.26_bk/ blast-2.2.26 

## Copy over remaining required files
COPY input_prep/make_ss.sh /opt/RoseTTAFold-AA/make_ss.sh
RUN chmod +x make_ss.sh
COPY make_msa_no_signalp.sh /opt/RoseTTAFold-AA/make_msa.sh
RUN chmod +x make_msa.sh

# For hardcoded path and package management
COPY __init__.py /opt/RoseTTAFold-AA/__init__.py
COPY RFAA_paper_weights.pt /opt/RoseTTAFold-AA/RFAA_paper_weights.pt

ENTRYPOINT [ "python", "-m", "rf2aa.run_inference" ]