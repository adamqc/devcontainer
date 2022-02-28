# Build stage with Spack pre-installed and ready to be used
FROM spack/ubuntu-jammy:latest as builder


# What we want to install and how we want to install it
# is specified in a manifest file (spack.yaml)
RUN mkdir /opt/spack-environment \
&&  (echo "spack:" \
&&   echo "  specs:" \
&&   echo "  - cmake" \
&&   echo "  - dealii+mpi+petsc+p4est+python+trilinos~hdf5~gmsh~sundials~oce~cgal~assimp~symengine" \
&&   echo "  - eigen" \
&&   echo "  - python" \
&&   echo "  - mfem@develop+mpi+petsc+suite-sparse+superlu-dist" \
&&   echo "  - mumps+mpi+metis+parmetis" \
&&   echo "  - petsc+hypre+mumps+superlu-dist" \
&&   echo "  - tetgen" \
&&   echo "  - valgrind" \
&&   echo "  - nanoflann" \
&&   echo "  packages:" \
&&   echo "    all:" \
&&   echo "      target:" \
&&   echo "      - x86_64" \
&&   echo "  concretizer:" \
&&   echo "    unify: true" \
&&   echo "  config:" \
&&   echo "    install_tree: /opt/software" \
&&   echo "  view: /opt/view") > /opt/spack-environment/spack.yaml

# Install the software, remove unnecessary deps
RUN cd /opt/spack-environment && spack env activate . && spack install --fail-fast && spack gc -y

# Strip all the binaries
RUN find -L /opt/view/* -type f -exec readlink -f '{}' \; | \
    xargs file -i | \
    grep 'charset=binary' | \
    grep 'x-executable\|x-archive\|x-sharedlib' | \
    awk -F: '{print $1}' | xargs strip -s

# Modifications to the environment that are necessary to run
RUN cd /opt/spack-environment && \
    spack env activate --sh -d . >> /etc/profile.d/z10_spack_environment.sh

# Bare OS image to run the installed executables
FROM ubuntu:22.04

COPY --from=builder /opt/spack-environment /opt/spack-environment
COPY --from=builder /opt/software /opt/software
COPY --from=builder /opt/._view /opt/._view
COPY --from=builder /opt/view /opt/view
COPY --from=builder /etc/profile.d/z10_spack_environment.sh /etc/profile.d/z10_spack_environment.sh

RUN apt-get -yqq update && apt-get -yqq upgrade \
 && apt-get -yqq install build-essential clang-format gfortran git \
 && rm -rf /var/lib/apt/lists/*

RUN /opt/view/bin/python -m pip install scipy numpy scipy matplotlib pandas -i https://pypi.org/simple && rm -rf /root/.cache
ENV OMPI_ALLOW_RUN_AS_ROOT=1 OMPI_ALLOW_RUN_AS_ROOT_CONFIRM=1
RUN echo "source /etc/profile" >> /root/.bashrc
USER root
WORKDIR /root

ENTRYPOINT ["/bin/bash", "--rcfile", "/etc/profile", "-l", "-c", "$*", "--" ]
CMD [ "/bin/bash" ]

