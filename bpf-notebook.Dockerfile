FROM quay.io/jupyter/minimal-notebook:x86_64-ubuntu-24.04 

USER root
RUN apt update  --yes && apt install --yes --no-install-recommends libelf-dev && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN chmod 777 /home/jovyan 
RUN echo "jovyan ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers
USER ${NB_UID}

CMD ["sudo", "jupyterhub-singleuser", "--allow-root"]
