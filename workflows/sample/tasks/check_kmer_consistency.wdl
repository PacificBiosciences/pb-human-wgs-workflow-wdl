version 1.0

task check_kmer_consistency {
  input {
    String sample_name
    File ref_modimers
    Array[File?] movie_modimers
    String log_name = "check_kmer_consistency.log"

    String output_name = "~{sample_name}.kmerconsistency.txt"
    String pb_conda_image

    Int threads = 4
  }

  Int disk_size = 500

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    source activate base_python3
    echo "$(conda info)"

    (python3 /opt/pb/scripts/check_kmer_consistency.py ~{ref_modimers}  ~{sep=" " movie_modimers} > ~{output_name}) > ~{log_name} 2>&1
  >>>
  output {
    File check_kmer_consistency_output_name = "~{output_name}"
    File log = "~{log_name}"
 }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "100 GB"
    cpu: "~{threads}"
    disk: disk_size + " GB"
  }
}
