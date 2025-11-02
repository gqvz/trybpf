FROM quay.io/jupyter/minimal-notebook:x86_64-ubuntu-24.04 

USER root
RUN apt update  --yes && apt install --yes --no-install-recommends clang libelf-dev python3 python3-pip build-essentials && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN ln /usr/bin/llc-18 /usr/bin/llc
RUN pip install pythonbpf pylibbpf --break-system-packages
RUN chmod 777 /home/jovyan 
RUN echo "jovyan ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER ${NB_UID}

CMD ["sudo", "jupyterhub-singleuser", "--allow-root"]
