version 1.0

task bgzip_vcf {
  input {
    Int threads = 2
    String log_name = "bgzip_vcf.log"
    File vcf # f"cohorts/{cohort}/{{prefix}}.vcf"
    String pb_conda_image
  }

  command <<<
    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

#    (bgzip --threads ~{threads} ~{vcf}) > ~{log_name} 2>&1
  >>>
  output {
    File outfile1 = stdout()

#    File vcf_gz = "bgzip.vcf.gz" # f"cohorts/{cohort}/{{prefix}}.vcf.gz"
    File vcf_gz = stdout()
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

task tabix_vcf {
  input {
    String params = "-p vcf"
    File vcf_gz # f"cohorts/{cohort}/{{prefix}}.vcf.gz"
    String log_name = "tabix_vcf.log"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

#    (tabix ~{params} ~{vcf_gz}) > ~{log_name} 2>&1
  >>>
  output {
    File outfile1 = stdout()

#    File vcf_gz_tbi = "tabix.vcf.gz.tbi" # f"cohorts/{cohort}/{{prefix}}.vcf.gz.tbi"
    File vcf_gz_tbi = stdout()
#    File log = "~{log_name}"
    File log = stdout()
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

task tabix_bcf {
  input {
    String params = "-p bcf"
    String log_name = "tabix_bcf.log"
    File bcf # f"cohorts/{cohort}/{{prefix}}.bcf"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

#    (tabix ~{params} ~{bcf}) > ~{log_name} 2>&1
  >>>
  output {
    File outfile1 = stdout()
#    File log = "~{log_name}"
    File log = stdout()

#    File bcf_csi = "tabix_bcf.bcf.csi" # temp(f"cohorts/{cohort}/{{prefix}}.bcf.csi")
    File bcf_csi = stdout()
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

task create_ped {
  input {
    String log_name = "create_ped.log"
    File allyaml # config['cohort_yaml']
    String ped_name = "cohort.ped" # f"cohorts/{cohort}/{cohort}.ped"
    String cohort

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate yaml2ped
    echo "$(conda info)"

#    shell: (python3 /opt/pb/scripts/yaml2ped.py ~{allyaml} ~{cohort} ~{ped_name}) > ~{log_name} 2>&1
  >>>
  output {
    File outfile1 = stdout()
#    File log = "~{log_name}"
    File log = stdout()

#    File ped = "~{ped_name}"
    File ped = stdout()
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

task calculate_phrank {
  input {
    String log_name = "calculate_phrank.log"
    File hpoterms #= config['hpo']['terms'],
    File hpodag #= config['hpo']['dag'],
    File hpoannotations #= config['hpo']['annotations'],
    File ensembltohgnc #= config['ensembl_to_hgnc'],
    File allyaml #= config['cohort_yaml']
    String cohort

    File phrank_tsv_name = "phrank.tsv" #output: f"cohorts/{cohort}/{cohort}_phrank.tsv"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate phrank
    echo "$(conda info)"

#    (python3 /opt/pb/scripts/calculate_phrank.py \
#        ~{hpoterms} ~{hpodag} ~{hpoannotations} \
#        ~{ensembltohgnc} ~{allyaml} ~{cohort} ~{phrank_tsv_name}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File phrank_tsv = "~{phrank_tsv_name}"
  }
  runtime {
    docker: "~{pb_conda_image}"
    preemptible: true
    maxRetries: 3
    memory: "14 GB"
    cpu: "~{threads}"
    disk: "200 GB"
  }
}

workflow common {
  input {
    File vcf # f"cohorts/{cohort}/{{prefix}}.vcf"
    File vcf_gz
    File bcf # f"cohorts/{cohort}/{{prefix}}.bcf"
    File hpoterms #= config['hpo']['terms'],
    File hpodag #= config['hpo']['dag'],
    File hpoannotations #= config['hpo']['annotations'],
    File ensembltohgnc #= config['ensembl_to_hgnc'],
    File allyaml #= config['cohort_yaml']
    String cohort
    String pb_conda_image
  }

#  call bgzip_vcf {
#    input:
#      vcf = vcf,
#      pb_conda_image = pb_conda_image
#  }

  call tabix_vcf {
    input:
      vcf_gz = vcf_gz,
      pb_conda_image = pb_conda_image
  }

#  call tabix_bcf {
#    input:
#      bcf = bcf,
#      pb_conda_image = pb_conda_image
#  }

#  call create_ped {
#    input:
#      allyaml = allyaml,
#      cohort = cohort,
#      pb_conda_image = pb_conda_image
#  }

#  call calculate_phrank {
#    input:
#      hpoterms = hpoterms,
#      hpodag = hpodag,
#      hpoannotations = hpoannotations,
#      ensembltohgnc = ensembltohgnc, 
#      allyaml = allyaml, 
#      cohort = cohort,
#      pb_conda_image = pb_conda_image
#  }

  output {
#    File bgzip_vcf_outfile = bgzip_vcf.outfile1
#    File tabix_vcf_outfile = tabix_vcf.outfile1
#    File tabix_bcf_outfile = tabix_bcf.outfile1
#    File create_ped_outfile = create_ped.outfile1
#    File calculate_phrank_outfile = calculate_phrank.outfile1

#    File bgzip_vcf_gz = bgzip_vcf.vcf_gz
#    File vcf_gz_tbi = tabix_vcf.vcf_gz_tbi
#    File bcf_csi = tabix_bcf.bcf_csi
#    File ped = create_ped.ped
#    File phrank_tsv = calculate_phrank.phrank_tsv

  }
}
