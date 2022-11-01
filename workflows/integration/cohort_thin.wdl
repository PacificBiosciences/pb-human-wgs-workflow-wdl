version 1.0

#to run cohort.wdl standalone

#import "../common/structs.wdl"
#import "../cohort/cohort.wdl"

import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/cohort/cohort.wdl"

struct PacBioInfo {
  String name
  String path
  Array[String] movie
}

workflow cohort_thin {
  input {
    String cohort_name
    File regions_file
    IndexedData reference
    File chr_lengths

    File hpoannotations
    File hpoterms
    File hpodag
    File gff
    File ensembl_to_hgnc
    File js
    File lof_lookup
    File clinvar_lookup
    File gnomad_af
    File hprc_af
    File allyaml
    File ped

    String pb_conda_image
    String glnexus_image

    Array[PacBioInfo] data_info
  }

  Array[String] regions = read_lines(regions_file)

  String phase_tag = "hg38.deepvariant.phased.vcf.gz"
  scatter (sample in data_info) {
    IndexedData phased_vcf = {"datafile":"~{sample.path}/~{sample.name}.~{phase_tag}", "indexfile":"~{sample.path}/~{sample.name}.~{phase_tag}.tbi"}
  }
  Array[IndexedData] person_deepvariant_phased_vcf_gz = phased_vcf

  String gvcf_tag = "hg38.deepvariant.g.vcf.gz"
  scatter (sample in data_info) {
    IndexedData gvcf = {"datafile":"~{sample.path}/~{sample.name}.~{gvcf_tag}", "indexfile":"~{sample.path}/~{sample.name}.~{gvcf_tag}.tbi"}
  }
  Array[IndexedData] person_gvcfs = gvcf

  scatter (sample in data_info) {
    scatter (movie in sample.movie) {
      IndexedData bam = {"datafile":"~{sample.path}/~{movie}.hg38.bam", "indexfile":"~{sample.path}/~{movie}.hg38.bam.bai"}
    }
  }
  Array[Array[IndexedData]] person_bams = bam

  scatter (sample in data_info) {
    scatter (region in regions){
      scatter (movie in sample.movie) {
        String svsigs = "~{sample.path}/svsigs/~{movie}.hg38.~{region}.svsig.gz"
      }
    }
  }
  Array[Array[Array[File]]] person_svsigs = svsigs

  call cohort.cohort {
    input:
      cohort_name = cohort_name,
      regions = regions,
      reference = reference,

      person_deepvariant_phased_vcf_gz = person_deepvariant_phased_vcf_gz,

      chr_lengths = chr_lengths,

      hpoannotations = hpoannotations,
      hpoterms = hpoterms,
      hpodag = hpodag,
      gff = gff,
      ensembl_to_hgnc = ensembl_to_hgnc,
      js = js,
      lof_lookup = lof_lookup,
      clinvar_lookup = clinvar_lookup,
      gnomad_af = gnomad_af,
      hprc_af = hprc_af,
      allyaml = allyaml,
      ped = ped,

      pb_conda_image = pb_conda_image,
      glnexus_image = glnexus_image,

      #copied from sample_family.person_deepvariant_phased_vcf_gz
      person_deepvariant_phased_vcf_gz = person_deepvariant_phased_vcf_gz,
      person_svsigs = person_svsigs, #copied from sample_family.person_svsigs
      person_gvcfs = person_gvcfs, #copied from sample_family.person_gvcfs
      person_bams = person_bams #copied from smrtcells_cohort.person_bams
  }

  output {
  }
}
