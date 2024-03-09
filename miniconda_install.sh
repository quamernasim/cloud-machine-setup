wget https://repo.anaconda.com/miniconda/Miniconda3-latest-Linux-x86_64.sh
mv Miniconda3-latest-Linux-x86_64.sh ..
bash ../Miniconda3-latest-Linux-x86_64.sh
conda create --name quamer --clone base
# eval "$(/home/ubuntu/quamer/miniconda3/bin/conda shell.bash hook)"
