version 1.0

import "../structs/BamPair.wdl"
import "./common_bgzip_vcf.wdl" as bgzip_vcf

task reformat_ensembl_gff {
  input {
    String url
    String log_name = "reformat_ensembl_gff.log" 

    String ensembl_gff_name = "ensembl.GRCh38.101.reformatted.gff3.gz"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    (wget -qO - ~{url} | zcat \
        | awk -v OFS="\t" '{{ if ($1=="##sequence-region") && ($2~/^G|K/) {{ print $0; }} else if ($0!~/G|K/) {{ print "chr" $0; }} }}' \
        | bgzip > ~{ensembl_gff_name}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File ensembl_gff = "~{ensembl_gff_name}"
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

task generate_lof_lookup {
  input {
    String url 
    String log_name = "generate_lof_lookup.log"
    String lof_lookup_name = "lof_lookup.txt"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate samtools
    echo "$(conda info)"

    (wget -qO - ~{url} | zcat | cut -f 1,21,24 | tail -n+2 \
        | awk "{{ printf(\\"%s\\tpLI=%.3g;oe_lof=%.5g\\n\\", \$1, \$2, \$3) }}" > ~{lof_lookup_name}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File lof_lookup = "~{lof_lookup_name}"
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

task generate_clinvar_lookup {
  input {
    String url
    String log_name = "generate_clinvar_lookup.log"
    String clinvar_lookup_name = "clinvar_gene_desc.txt"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate samtools
    echo "$(conda info)"

    (wget -qO - ~{url} | cut -f 2,5 | grep -v ^$'\t' > ~{clinvar_lookup_name}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File clinvar_lookup = "~{clinvar_lookup_name}"
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

task bcftools_norm {
  input {
    String cohort_name
    IndexedData reference
    String log_name = "bcftools_norm.log"

    IndexedData? vcf

    String deepvariant_phased_norm_bcf_name = "~{cohort_name}.~{reference.name}.deepvariant.phased.norm.bcf"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate bcftools
    echo "$(conda info)"

    (bcftools norm --multiallelics - --output-type b -f ~{reference.datafile} ~{select_first([vcf]).datafile} -o ~{deepvariant_phased_norm_bcf_name}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File deepvariant_phased_norm_bcf = "~{deepvariant_phased_norm_bcf_name}"
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
    File bcf_datafile
    String bcf_datafile_name = "~{basename(bcf_datafile)}"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate htslib
    echo "$(conda info)"

    mv ~{bcf_datafile} ~{bcf_datafile_name}
    (tabix ~{params} ~{bcf_datafile_name}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    IndexedData bcf = { "datafile": "~{bcf_datafile_name}", "indexfile": "~{bcf_datafile_name}.csi" }
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

task slivar_small_variant {
  input {
    Int threads = 12
    String log_name = "slivar_small_variant.log"

    String cohort_name
    Boolean singleton
    IndexedData bcf
    File ped
    File gnomad_af
    File hprc_af
    File js
    File gff
    IndexedData reference

    String deepvariant_phased_slivar_vcf_name = "~{cohort_name}.~{reference.name}.deepvariant.phased.slivar.vcf"

    Array[String] singleton_slivar_filters = [
            "--info 'variant.FILTER==\"PASS\" && INFO.gnomad_af < 0.01 && INFO.hprc_af < 0.01 && INFO.gnomad_nhomalt < 5 && INFO.hprc_nhomalt < 5'",
            "--family-expr 'recessive:fam.every(segregating_recessive)'",
            "--family-expr 'x_recessive:(variant.CHROM == \"chrX\") && fam.every(segregating_recessive_x)'",
            "--family-expr 'dominant:fam.every(segregating_dominant) && INFO.gnomad_ac < 5 && INFO.hprc_ac < 5'",
            "--family-expr 'x_dominant:(variant.CHROM == \"chrX\") && fam.every(segregating_dominant_x) && INFO.gnomad_ac < 5 && INFO.hprc_ac < 5'",
            "--sample-expr 'comphet_side:sample.het && sample.GQ > 5'"
            ]

    Array[String] non_singleton_slivar_filters = [
            "--info 'variant.FILTER==\"PASS\" && INFO.gnomad_af < 0.01 && INFO.hprc_af < 0.01 && INFO.gnomad_nhomalt < 5 && INFO.hprc_nhomalt < 5'",
            "--family-expr 'recessive:fam.every(segregating_recessive)'",
            "--family-expr 'x_recessive:(variant.CHROM == \"chrX\") && fam.every(segregating_recessive_x)'",
            "--family-expr 'dominant:fam.every(segregating_dominant) && INFO.gnomad_ac < 5 && INFO.hprc_ac < 5'",
            "--family-expr 'x_dominant:(variant.CHROM == \"chrX\") && fam.every(segregating_dominant_x) && INFO.gnomad_ac < 5 && INFO.hprc_ac < 5'",
            "--trio 'comphet_side:comphet_side(kid, mom, dad) && kid.affected'"
        ]

    Array[String] slivar_filters = if singleton then singleton_slivar_filters else non_singleton_slivar_filters

    String pb_conda_image
  }

  command <<<
    source ~/.bashrc
    conda activate slivar
    echo "$(conda info)"

    (pslivar --processes ~{threads} \
        --fasta ~{reference.datafile}\
        --pass-only \
        --js ~{js} \
        ~{sep=" " slivar_filters} \
        --gnotate ~{gnomad_af} \
        --vcf ~{bcf.datafile} \
        --ped ~{ped} \
        | bcftools csq -l -s - --ncsq 40 \
            -g ~{gff} -f ~{reference.datafile} - -o ~{deepvariant_phased_slivar_vcf_name}) > ~{log_name} 2>&1

#  hprc was removed
#    (pslivar --processes ~{threads} \
#        --fasta ~{reference.datafile}\
#        --pass-only \
#        --js ~{js} \
#        ~{sep="," slivar_filters} \
#        --gnotate ~{gnomad_af} \
#        --gnotate ~{hprc_af} \
#        --vcf ~{bcf.datafile} \
#        --ped ~{ped} \
#        | bcftools csq -l -s - --ncsq 40 \
#            -g ~{gff} -f ~{reference.datafile} - -o ~{deepvariant_phased_slivar_vcf_name}) > ~{log_name} 2>&1


  >>>
  output {
    File log = "~{log_name}"
    File deepvariant_phased_slivar_vcf = "~{deepvariant_phased_slivar_vcf_name}"
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

task slivar_compound_hets {
  input {
    String log_name = "slivar_compound_hets.log"

    String cohort_name
    String? reference_name
    IndexedData vcf
    File ped

    String deepvariant_phased_slivar_compound_hets_vcf_name = "~{cohort_name}.~{reference_name}.deepvariant.phased.slivar.compound-hets.vcf" 

    Array[String] skip_list = [
      "non_coding_transcript",
      "intron",
      "non_coding_transcript",
      "non_coding",
      "upstream_gene",
      "downstream_gene",
      "non_coding_transcript_exon",
      "NMD_transcript",
      "5_prime_UTR",
      "3_prime_UTR"
    ]

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate slivar
    echo "$(conda info)"

    (slivar compound-hets \
        --skip ~{sep="," skip_list} \
        --vcf ~{vcf.datafile} \
        --sample-field comphet_side \
        --ped ~{ped} \
        --allow-non-trios \
        | python3 /opt/pb/scripts/add_comphet_phase.py \
        > ~{deepvariant_phased_slivar_compound_hets_vcf_name}) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File deepvariant_phased_slivar_compound_hets_vcf = "~{deepvariant_phased_slivar_compound_hets_vcf_name}"
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
    String cohort_name

    File phrank_tsv_name = "~{cohort_name}_phrank.tsv"

    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate phrank
    echo "$(conda info)"

    (python3 /opt/pb/scripts/calculate_phrank.py \
        ~{hpoterms} ~{hpodag} ~{hpoannotations} \
        ~{ensembltohgnc} ~{allyaml} ~{cohort_name} ~{phrank_tsv_name}) > ~{log_name} 2>&1
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


task slivar_tsv {
  input {
    String log_name = "slivar_tsv.log"

    String cohort_name
    String? reference_name
    IndexedData filt_vcf
    File comphet_vcf #= f"cohorts/{cohort}/slivar/{cohort}.{ref}.deepvariant.phased.slivar.compound-hets.vcf.gz",
    File ped #= f"cohorts/{cohort}/{cohort}.ped",
    File lof_lookup #= config['lof_lookup'],
    File clinvar_lookup #= config['clinvar_lookup'],
    File phrank_lookup #= f"cohorts/{cohort}/{cohort}_phrank.tsv"

    String filt_tsv_name = "~{cohort_name}.~{reference_name}.deepvariant.phased.slivar.tsv" #= f"cohorts/{cohort}/slivar/{cohort}.{ref}.deepvariant.phased.slivar.tsv",
    String comphet_tsv_name = "~{cohort_name}.~{reference_name}.deepvariant.phased.slivar.compound-hets.tsv" #= f"cohorts/{cohort}/slivar/{cohort}.{ref}.deepvariant.phased.slivar.compound-hets.tsv"

    Array[String] info_fields = [
      "gnomad_af",
      "hprc_af",
      "gnomad_nhomalt",
      "hprc_nhomalt",
      "gnomad_ac",
      "hprc_ac"
    ]
    String pb_conda_image
    Int threads = 4
  }

  command <<<
    source ~/.bashrc
    conda activate slivar
    echo "$(conda info)"

    (
      slivar tsv \
            ~{sep=" --info-field " info_fields } \
            --sample-field dominant \
            --sample-field x_dominant \
            --sample-field recessive \
            --sample-field x_recessive \
            --csq-field BCSQ \
            --gene-description ~{lof_lookup} \
            --gene-description ~{clinvar_lookup} \
            --gene-description ~{phrank_lookup} \
            --ped ~{ped} \
            --out {output.filt_tsv} \
            {input.filt_vcf.datafile}
      slivar tsv \
            ~{sep=" --info-field " info_fields } \
            --sample-field slivar_comphet \
            --info-field slivar_comphet \
            --csq-field BCSQ \
            --gene-description ~{lof_lookup} \
            --gene-description ~{clinvar_lookup} \
            --gene-description ~{phrank_lookup} \
            --ped {input.ped} \
            --out ~{comphet_tsv} \
            ~{comphet_vcf}
    ) > ~{log_name} 2>&1
  >>>
  output {
    File log = "~{log_name}"
    File filt_tsv = "~{filt_tsv_name}"
    File comphet_tsv = "~{comphet_tsv_name}"
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

workflow slivar {
  input {
    String cohort_name
    IndexedData reference

    Boolean singleton

    File lof_lookup
    File clinvar_lookup

    IndexedData? slivar_input

    File ped
    File gnomad_af
    File hprc_af
    File js
    File gff

    File hpoterms #= config['hpo']['terms'],
    File hpodag #= config['hpo']['dag'],
    File hpoannotations #= config['hpo']['annotations'],
    File ensembltohgnc #= config['ensembl_to_hgnc'],
    File allyaml #= config['cohort_yaml']

    String pb_conda_image
  }

  call reformat_ensembl_gff {
    input:
      url = gff,
      pb_conda_image = pb_conda_image
  }

  call generate_lof_lookup {
    input:
      url = lof_lookup,
      pb_conda_image = pb_conda_image
  }

  call generate_clinvar_lookup {
    input:
      url = clinvar_lookup,
      pb_conda_image = pb_conda_image
  }

  call bcftools_norm {
    input:
      cohort_name = cohort_name,
      reference = reference,
      vcf = slivar_input,
      pb_conda_image = pb_conda_image
  }

  call tabix_bcf {
    input:
      bcf_datafile = bcftools_norm.deepvariant_phased_norm_bcf,
      pb_conda_image = pb_conda_image
  }

  call slivar_small_variant {
    input:
      cohort_name = cohort_name,
      singleton = singleton,
      bcf = tabix_bcf.bcf,
      ped = ped,
      gnomad_af = gnomad_af,
      hprc_af = hprc_af,
      js = js,
      gff = reformat_ensembl_gff.ensembl_gff,
      reference = reference,
      pb_conda_image = pb_conda_image
  }

  call bgzip_vcf.bgzip_vcf {
    input :
      vcf_input = slivar_small_variant.deepvariant_phased_slivar_vcf,
      pb_conda_image = pb_conda_image
  }

  call slivar_compound_hets {
    input:
      cohort_name = cohort_name,
      reference_name = reference.name,
      vcf = bgzip_vcf.vcf_gz_output,
      ped = ped,

      pb_conda_image = pb_conda_image
  }

#  call calculate_phrank {
#    input:
#      hpoterms = hpoterms, #= config['hpo']['terms'],
#      hpodag = hpodag, #= config['hpo']['dag'],
#      hpoannotations = hpoannotations, #= config['hpo']['annotations'],
#      ensembltohgnc = ensembltohgnc, #= config['ensembl_to_hgnc'],
#      allyaml = allyaml, #= config['cohort_yaml']
#      cohort_name = cohort_name,

#      pb_conda_image = pb_conda_image
#  }

#  call slivar_tsv {
#    input:
#      cohort_name = cohort_name,
#      filt_vcf = bgzip_vcf.vcf_gz_output, 
#      comphet_vcf = slivar_compound_hets.deepvariant_phased_slivar_compound_hets_vcf, 
#      ped = ped, 
#      lof_lookup = generate_lof_lookup.lof_lookup, 
#      clinvar_lookup = generate_clinvar_lookup.clinvar_lookup, 
#      phrank_lookup = calculate_phrank.phrank_tsv,

#      pb_conda_image = pb_conda_image
#  }

  output {
  }
}


