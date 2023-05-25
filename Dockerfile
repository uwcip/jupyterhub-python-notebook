FROM ghcr.io/uwcip/jupyterhub-base-notebook:v1.8.5

# github metadata
LABEL org.opencontainers.image.source=https://github.com/uwcip/jupyterhub-python-notebook

USER root

# install updates and dependencies
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -q update && apt-get -y upgrade && \
    # ffmpeg for matplotlib anim & dvipng+cm-super for latex labels
    apt-get install -y --no-install-recommends ffmpeg dvipng cm-super && \
    # tesseract for OCR work
    apt-get install -y --no-install-recommends tesseract-ocr-all && \
    # Java for Spark
    apt-get install -y --no-install-recommends default-jdk && \
    # NLopt (non-linear optmization) package
    apt-get install -y --no-install-recommends libnlopt-dev && \
    apt-get clean && rm -rf /var/lib/apt/lists/*

USER ${NB_UID}

RUN echo ${NB_UID}

# install Python3 packages (only support commonly used packages, students should install their own packages)
RUN conda install --quiet --yes \
    "bokeh>=3.0.3" \
    "gensim>=4.3.0" \
    "matplotlib-base>=3.7.1" \
    "networkx>=3.1" \
    "nltk>=3.8.1" \
    "pandas>=2.0.1" \
    "psycopg2-binary>=2.9.3" \
    "scikit-learn>=1.2.2" \
    && conda clean --all -f -y \
    && fix-permissions "${CONDA_DIR}" \
    && fix-permissions "/home/${NB_USER}" \
    && true

# install facets which does not have a pip or conda package at the moment.
# according to the docs this does NOT require a call to "enable" the extension.
WORKDIR /tmp
RUN git clone https://github.com/PAIR-code/facets.git && \
    jupyter nbextension install facets/facets-dist/ --sys-prefix && \
    rm -rf /tmp/facets && \
    fix-permissions "${CONDA_DIR}" && \
    fix-permissions "/home/${NB_USER}"

# install datapy to access databricks
RUN pip install --upgrade pip
RUN --mount=type=secret,id=PYPI_PASSWORD,uid=1000 pip install --extra-index-url=https://$(cat /run/secrets/PYPI_PASSWORD)@pkgs.dev.azure.com/uwcip/uwcip/_packaging/uwcip-pypi-dev/pypi/simple datapy && \
fix-permissions "${CONDA_DIR}" && fix-permissions "/home/${NB_USER}"


# import matplotlib the first time to build the font cache.
ENV XDG_CACHE_HOME="/home/${NB_USER}/.cache/"
RUN MPLBACKEND=Agg python -c "import matplotlib.pyplot" && \
    fix-permissions "/home/${NB_USER}"

# ensure that we run the container as the notebook user
USER ${NB_UID}
WORKDIR ${HOME}
