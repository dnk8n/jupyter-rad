FROM jupyter/minimal-notebook:87210526f381

USER root

## For the next few sections, I copied official Julia Dockerfile to install Julia
## (https://github.com/docker-library/julia/blob/467c652ab40064be58ba83ed4448f139592c7525/0/stretch/Dockerfile)
## but made changes to the sha256 checksums which are available by looking at
## `docker history --no-trunc julia:0.6.4`

RUN set -eux; \
	apt-get update; \
	apt-get install -y --no-install-recommends \
		ca-certificates \
# ERROR: no download agent available; install curl, wget, or fetch
		curl \
	; \
	rm -rf /var/lib/apt/lists/*

ENV JULIA_PATH /usr/local/julia
ENV PATH $JULIA_PATH/bin:$PATH

# https://julialang.org/juliareleases.asc
# Julia (Binary signing key) <buildbot@julialang.org>
ENV JULIA_GPG 3673DF529D9049477F76B37566E3C7DC03D6E495

# https://julialang.org/downloads/
ENV JULIA_VERSION 0.6.4

RUN set -eux; \
	\
	savedAptMark="$(apt-mark showmanual)"; \
	if ! command -v gpg > /dev/null; then \
		apt-get update; \
		apt-get install -y --no-install-recommends \
			gnupg \
			dirmngr \
		; \
		rm -rf /var/lib/apt/lists/*; \
	fi; \
	\
# https://julialang.org/downloads/#julia-command-line-version
# https://julialang-s3.julialang.org/bin/checksums/julia-0.7.0.sha256
# this "case" statement is generated via "update.sh"
	dpkgArch="$(dpkg --print-architecture)"; \
	case "${dpkgArch##*-}" in \
# amd64
		amd64) tarArch='x86_64'; dirArch='x64'; sha256='d20e6984bcf8c3692d853a9922e2cf1de19b91201cb9e396d9264c32cebedc46' ;; \
# i386
		i386) tarArch='i686'; dirArch='x86'; sha256='ab45280c799e63ab04da7a928fee79b43e41b457a6d4c48058798b9bad542688' ;; \
		*) echo >&2 "error: current architecture ($dpkgArch) does not have a corresponding Julia binary release"; exit 1 ;; \
	esac; \
	\
	folder="$(echo "$JULIA_VERSION" | cut -d. -f1-2)"; \
	curl -fL -o julia.tar.gz.asc "https://julialang-s3.julialang.org/bin/linux/${dirArch}/${folder}/julia-${JULIA_VERSION}-linux-${tarArch}.tar.gz.asc"; \
	curl -fL -o julia.tar.gz     "https://julialang-s3.julialang.org/bin/linux/${dirArch}/${folder}/julia-${JULIA_VERSION}-linux-${tarArch}.tar.gz"; \
	\
	echo "${sha256} *julia.tar.gz" | sha256sum -c -; \
	\
	export GNUPGHOME="$(mktemp -d)"; \
	cat "$GNUPGHOME"/dirmngr.conf; \
	echo "disable-ipv6" >> "$GNUPGHOME"/dirmngr.conf; \
	gpg --batch --keyserver ha.pool.sks-keyservers.net --recv-keys "$JULIA_GPG"; \
	gpg --batch --verify julia.tar.gz.asc julia.tar.gz; \
	command -v gpgconf > /dev/null && gpgconf --kill all; \
	# Add a sleep here, else files are still writing to the directory as you attempt to remove it
	sleep 10; \
	rm -rf "$GNUPGHOME" julia.tar.gz.asc; \
	\
	mkdir "$JULIA_PATH"; \
	tar -xzf julia.tar.gz -C "$JULIA_PATH" --strip-components 1; \
	rm julia.tar.gz; \
	\
	apt-mark auto '.*' > /dev/null; \
	[ -z "$savedAptMark" ] || apt-mark manual $savedAptMark; \
	apt-get purge -y --auto-remove -o APT::AutoRemove::RecommendsImportant=false; \
	\
# smoke test
	julia --version

## Now to install Julia as a kernel (iJulia), RAD, Rifraf, Compat, StatsBase

USER 1000

RUN /opt/conda/bin/conda update ipykernel; \
    /opt/conda/bin/conda clean --all; \
    /opt/conda/bin/conda update --all; \
    /opt/conda/bin/conda install matplotlib;

RUN julia -e ' \
        Pkg.init(); Pkg.update(); \
        Pkg.add("Compat"); using Compat; \
        Pkg.add("IJulia"); using IJulia; \
        Pkg.add("StatsBase"); using StatsBase; \
        Pkg.clone("https://github.com/MurrellGroup/Rifraf.jl"); using Rifraf; \
        Pkg.clone("https://github.com/MurrellGroup/NextGenSeqUtils.jl");  using NextGenSeqUtils; \
        Pkg.clone("https://github.com/MurrellGroup/DPMeansClustering.jl"); using DPMeansClustering; \
        Pkg.clone("https://github.com/MurrellGroup/RobustAmpliconDenoising.jl"); using RobustAmpliconDenoising; \
    '
