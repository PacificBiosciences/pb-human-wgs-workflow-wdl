for f in $(ls /opt/pb/envs/*)
do	
	name=$(basename "$f" .yaml)
	
	echo "Creating environment: $name"
	/opt/conda/bin/conda env create -f $f --name $name
    echo "source activate $name" >> ~/.bashrc
     PATH=/opt/pb/envs/$name/bin:$PATH
done;
export PATH
