FROM nfcore/base:2.1

LABEL base.image="nfcore/base:2.1"
LABEL software="Bactopia - minmers"
LABEL software.version="2.1.1"
LABEL description="A flexible pipeline for complete analysis of bacterial genomes"
LABEL website="https://bactopia.github.io/"
LABEL license="https://github.com/bactopia/bactopia/blob/master/LICENSE"
LABEL maintainer="Robert A. Petit III"
LABEL maintainer.email="robert.petit@emory.edu"
LABEL conda.env="bactopia/conda/linux/minmers.yml"
LABEL conda.md5="b3046acacda7251fd9b2d6e15bdc4234"

COPY conda/linux/minmers.yml /
RUN conda env create -q -f minmers.yml && conda clean -y -a
ENV PATH /opt/conda/envs/bactopia-minmers/bin:$PATH
COPY bin/*.py /opt/conda/envs/bactopia-minmers/bin/
