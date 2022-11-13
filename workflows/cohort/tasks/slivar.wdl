version 1.0

import "../../common/structs.wdl"
import "./common_bgzip_vcf.wdl" as bgzip_vcf


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

#  Float multiplier = 3.25
#  Int disk_size = ceil(multiplier * (size(reference.datafile, "GB") + size(reference.indexfile, "GB") + size(select_first([vcf]).datafile, "GB") + size(select_first([vcf]).indexfile, "GB"))) + 20
  Int disk_size = 200

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
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
    disk: disk_size + " GB"
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

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * size(bcf_datafile, "GB")) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
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
    disk: disk_size + " GB"
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

#  Float multiplier = 3.25
#  Int disk_size = ceil(multiplier * (size(reference.datafile, "GB") + size(reference.indexfile, "GB") + size(bcf.datafile, "GB") + size(bcf.indexfile, "GB") + size(ped, "GB") + size(gnomad_af, "GB") + size(hprc_af, "GB") + size(js, "GB") + size(gff, "GB"))) + 20
  Int disk_size = 200

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate slivar
    echo "$(conda info)"

    (pslivar --processes ~{threads} \
        --fasta ~{reference.datafile}\
        --pass-only \
        --js ~{js} \
        ~{sep=" " slivar_filters} \
        --gnotate ~{gnomad_af} \
        --gnotate ~{hprc_af} \
        --vcf ~{bcf.datafile} \
        --ped ~{ped} \
        | bcftools csq -l -s - --ncsq 40 \
            -g ~{gff} -f ~{reference.datafile} - -o ~{deepvariant_phased_slivar_vcf_name}) > ~{log_name} 2>&1


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
    disk: disk_size + " GB"
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

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(vcf.datafile, "GB") + size(vcf.indexfile, "GB") + size(ped, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
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
    disk: disk_size + " GB"
  }
}

task calculate_phrank {
  input {
    String log_name = "calculate_phrank.log"
    File hpoterms
    File hpodag
    File hpoannotations
    File ensembl_to_hgnc
    File allyaml
    String cohort_name

    String phrank_tsv_name = "~{cohort_name}_phrank.tsv"

    String pb_conda_image
    Int threads = 4
  }

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(hpoterms, "GB") + size(hpodag, "GB") + size(hpoannotations, "GB") + size(ensembl_to_hgnc, "GB") + size(allyaml, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate pyyaml
    echo "$(conda info)"

    (python3 /opt/pb/scripts/calculate_phrank.py \
        ~{hpoterms} ~{hpodag} ~{hpoannotations} \
        ~{ensembl_to_hgnc} ~{allyaml} ~{cohort_name} ~{phrank_tsv_name}) > ~{log_name} 2>&1
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
    disk: disk_size + " GB"
  }
}


task slivar_tsv {
  input {
    String log_name = "slivar_tsv.log"

    String cohort_name
    String? reference_name
    IndexedData filt_vcf
    IndexedData comphet_vcf
    File ped
    File lof_lookup
    File clinvar_lookup
    File phrank_lookup

    String filt_tsv_name = "~{cohort_name}.~{reference_name}.deepvariant.phased.slivar.tsv"
    String comphet_tsv_name = "~{cohort_name}.~{reference_name}.deepvariant.phased.slivar.compound-hets.tsv"

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

  Float multiplier = 3.25
  Int disk_size = ceil(multiplier * (size(filt_vcf.datafile, "GB") + size(filt_vcf.indexfile, "GB") + size(comphet_vcf.datafile, "GB") + size(comphet_vcf.indexfile, "GB") + size(ped, "GB") + size(lof_lookup, "GB") + size(clinvar_lookup, "GB") + size(phrank_lookup, "GB"))) + 20

  command <<<
    echo requested disk_size =  ~{disk_size}
    echo
    source ~/.bashrc
    conda activate slivar
    echo "$(conda info)"

    (
      slivar tsv \
            --info-field ~{sep=" --info-field " info_fields } \
            --sample-field dominant \
            --sample-field x_dominant \
            --sample-field recessive \
            --sample-field x_recessive \
            --csq-field BCSQ \
            --gene-description ~{lof_lookup} \
            --gene-description ~{clinvar_lookup} \
            --gene-description ~{phrank_lookup} \
            --ped ~{ped} \
            --out ~{filt_tsv_name} \
            ~{filt_vcf.datafile}
      slivar tsv \
            --info-field ~{sep=" --info-field " info_fields } \
            --sample-field slivar_comphet \
            --info-field slivar_comphet \
            --csq-field BCSQ \
            --gene-description ~{lof_lookup} \
            --gene-description ~{clinvar_lookup} \
            --gene-description ~{phrank_lookup} \
            --ped ~{ped} \
            --out ~{comphet_tsv_name} \
            ~{comphet_vcf.datafile}
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
    disk: disk_size + " GB"
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

    File hpoterms
    File hpodag
    File hpoannotations
    File ensembl_to_hgnc
    File allyaml

    String pb_conda_image
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
      gff = gff,
      reference = reference,
      pb_conda_image = pb_conda_image
  }

  call bgzip_vcf.bgzip_vcf as slivar_small_variant_bgzip_vcf {
    input :
      vcf_input = slivar_small_variant.deepvariant_phased_slivar_vcf,
      pb_conda_image = pb_conda_image
  }

  call slivar_compound_hets {
    input:
      cohort_name = cohort_name,
      reference_name = reference.name,
      vcf = slivar_small_variant_bgzip_vcf.vcf_gz_output,
      ped = ped,

      pb_conda_image = pb_conda_image
  }

  call bgzip_vcf.bgzip_vcf as slivar_compound_hets_bgzip_vcf {
    input :
      vcf_input = slivar_compound_hets.deepvariant_phased_slivar_compound_hets_vcf,
      pb_conda_image = pb_conda_image
  }

  call calculate_phrank {
    input:
      hpoterms = hpoterms,
      hpodag = hpodag,
      hpoannotations = hpoannotations,
      ensembl_to_hgnc = ensembl_to_hgnc,
      allyaml = allyaml,
      cohort_name = cohort_name,

      pb_conda_image = pb_conda_image
  }

  call slivar_tsv {
    input:
      cohort_name = cohort_name,
      reference_name = reference.name,
      filt_vcf = slivar_small_variant_bgzip_vcf.vcf_gz_output,
      comphet_vcf = slivar_compound_hets_bgzip_vcf.vcf_gz_output,
      ped = ped,
      lof_lookup = lof_lookup,
      clinvar_lookup = clinvar_lookup,
      phrank_lookup = calculate_phrank.phrank_tsv,

      pb_conda_image = pb_conda_image
  }

  output {
    IndexedData filt_vcf    = slivar_small_variant_bgzip_vcf.vcf_gz_output
    IndexedData comphet_vcf = slivar_compound_hets_bgzip_vcf.vcf_gz_output
    File filt_tsv = slivar_tsv.filt_tsv
    File comphet_tsv = slivar_tsv.comphet_tsv
  }
}
