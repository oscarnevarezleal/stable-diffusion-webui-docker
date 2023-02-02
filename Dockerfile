FROM ubuntu:20.04 AS build
ENV CONDA_ENV_NAME=automatic1111
USER root
RUN apt update && \
    apt install -y python3.9-full && \
    update-alternatives --install /usr/local/bin/python python /usr/bin/python3.9 1 && \
    apt-get install -yq wget git g++ cmake libglib2.0-0 && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/* && \
    echo 'PATH=/usr/local/bin:$PATH' >> ~/.bashrc

# Install miniconda
ENV CONDA_DIR /opt/conda
RUN wget --quiet https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh -O ~/miniconda.sh && \
/bin/bash ~/miniconda.sh -b -p /opt/conda
# Put conda in path so we can use conda activate
ENV PATH=$CONDA_DIR/bin:$PATH

RUN conda install -c conda-forge conda-pack

RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui
WORKDIR stable-diffusion-webui

RUN conda create --name "$CONDA_ENV_NAME" python=3.9 && \
    conda init bash && \
    eval "$(command conda 'shell.bash' 'hook' 2>/dev/null)" && \
    conda activate "$CONDA_ENV_NAME" && \
    pip install -r requirements.txt --extra-index-url https://download.pytorch.org/whl/cu113 && \
    conda install -n "$CONDA_ENV_NAME" pytorch torchvision torchaudio pytorch-cuda=11.6 -c pytorch -c nvidia  && \
    conda install xformers -c xformers/label/dev

# Use conda-pack to create a standalone enviornment
# in /venv:
RUN conda-pack -n "$CONDA_ENV_NAME" -o /tmp/env.tar && \
  mkdir /venv && cd /venv && tar xf /tmp/env.tar && \
  rm /tmp/env.tar

# We've put venv in same path it'll be in final image,
# so now fix up paths:
RUN /venv/bin/conda-unpack

FROM nvidia/cuda:11.6.0-runtime-ubuntu20.04
ENV DEBIAN_FRONTEND=noninteractive
ENV COMMANDLINE_ARGS="--skip-torch-cuda-test"
RUN apt-get update && apt-get install -y wget git ninja-build libglib2.0-0 libsm6 libxrender-dev libxext6 libgl1-mesa-glx
COPY --from=build /venv /venv
RUN git clone https://github.com/AUTOMATIC1111/stable-diffusion-webui
WORKDIR stable-diffusion-webui
RUN /bin/bash -c "source /venv/bin/activate \
    && python launch.py --precision full --no-half --exit || true"

ADD "https://huggingface.co/runwayml/stable-diffusion-v1-5/resolve/main/v1-5-pruned-emaonly.ckpt" models/Stable-diffusion/v1-5-pruned-emaonly.ckpt

# When image is run, run the code with the environment
# activated:
RUN echo "#!/bin/bash\n" \
    "source /venv/bin/activate && python webui.py --listen \$@ \n" > ./entrypoint.sh
RUN chmod +x entrypoint.sh
RUN cat entrypoint.sh
SHELL ["/bin/bash", "-c"]
ENTRYPOINT ["./entrypoint.sh" ]
