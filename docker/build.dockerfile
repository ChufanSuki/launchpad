ARG cpu_base_image="tensorflow/build:latest-python3.8"
ARG base_image=$cpu_base_image
FROM $base_image

LABEL maintainer="Chufan Chen <allenplato28@google.com>"
ARG tensorflow_pip="tf-nightly"
ARG python_version="3.8"
ARG APT_COMMAND="apt-get -o Acquire::Retries=3 -y"

# Stops tzdata from asking about timezones and blocking install on user input.
ARG DEBIAN_FRONTEND=noninteractive
ENV TZ=America/Los_Angeles

RUN apt-key adv --fetch-keys https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2004/x86_64/3bf863cc.pub
# Pick up some TF dependencies
RUN ${APT_COMMAND} update && ${APT_COMMAND} install -y --no-install-recommends \
        software-properties-common \
        aria2 \
        build-essential \
        curl \
        git \
        less \
        libfreetype6-dev \
        libhdf5-serial-dev \
        libpng-dev \
        libzmq3-dev \
        lsof \
        pkg-config \
        python3.8-dev \
        python3.9-dev \
        python3.10-dev \
        # python >= 3.8 needs distutils for packaging.
        python3.8-distutils \
        python3.9-distutils \
        python3.10-distutils \
        rename \
        rsync \
        sox \
        unzip \
        vim \
        && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN curl -O https://bootstrap.pypa.io/get-pip.py

# Installs known working version of bazel.
ARG bazel_version=3.7.2
ENV BAZEL_VERSION ${bazel_version}
RUN mkdir /bazel && \
    cd /bazel && \
    curl -fSsL -O https://github.com/bazelbuild/bazel/releases/download/$BAZEL_VERSION/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    chmod +x bazel-*.sh && \
    ./bazel-$BAZEL_VERSION-installer-linux-x86_64.sh && \
    cd / && \
    rm -f /bazel/bazel-$BAZEL_VERSION-installer-linux-x86_64.sh

ARG pip_dependencies=' \
        absl-py \
        contextlib2 \
        dm-tree>=0.1.5 \
        google-api-python-client \
        h5py \
        numpy \
        mock \
        oauth2client \
        pandas \
        portpicker'

RUN for version in ${python_version}; do \
    python$version get-pip.py && \
    # Replace TF version installed in the image by default with ${tensorflow_pip}
    python$version -mpip uninstall -y tensorflow tensorflow-gpu tf-nightly tf-nightly-gpu && \
    python$version -mpip --no-cache-dir install ${tensorflow_pip} --upgrade && \
    python$version -mpip --no-cache-dir install $pip_dependencies; \
    done
RUN rm get-pip.py

# Removes existing links so they can be created to point where we expect.
# See: https://superuser.com/questions/76061/how-do-i-make-rm-not-give-an-error-if-a-file-doesnt-exist
RUN rm /dt9/usr/include/x86_64-linux-gnu/python3.8 || true
RUN rm /dt9/usr/include/x86_64-linux-gnu/python3.9 || true
RUN rm /dt9/usr/include/x86_64-linux-gnu/python3.10 || true

# Needed until this is included in the base TF image.
RUN ln -s "/usr/include/x86_64-linux-gnu/python3.8" "/dt9/usr/include/x86_64-linux-gnu/python3.8"
RUN ln -s "/usr/include/x86_64-linux-gnu/python3.9" "/dt9/usr/include/x86_64-linux-gnu/python3.9"
RUN ln -s "/usr/include/x86_64-linux-gnu/python3.10" "/dt9/usr/include/x86_64-linux-gnu/python3.10"

# bazel build -c opt --copt=-mavx --config=manylinux2014 --test_output=errors //...

# Update binutils to avoid linker(gold) issue. See b/227299577#comment9
RUN wget http://old-releases.ubuntu.com/ubuntu/pool/main/b/binutils/binutils_2.35.1-1ubuntu1_amd64.deb \
    && wget http://old-releases.ubuntu.com/ubuntu/pool/main/b/binutils/binutils-x86-64-linux-gnu_2.35.1-1ubuntu1_amd64.deb \
    && wget http://old-releases.ubuntu.com/ubuntu/pool/main/b/binutils/binutils-common_2.35.1-1ubuntu1_amd64.deb \
    && wget http://old-releases.ubuntu.com/ubuntu/pool/main/b/binutils/libbinutils_2.35.1-1ubuntu1_amd64.deb

RUN dpkg -i binutils_2.35.1-1ubuntu1_amd64.deb \
            binutils-x86-64-linux-gnu_2.35.1-1ubuntu1_amd64.deb \
            binutils-common_2.35.1-1ubuntu1_amd64.deb \
            libbinutils_2.35.1-1ubuntu1_amd64.deb

WORKDIR "/tmp/launchpad"

CMD ["/bin/bash"]
