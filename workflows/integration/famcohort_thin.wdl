version 1.0

# famcohort_thin.wdl is to run sample.wdl/cohort.wdl using new data structure -- PacBioInfo, designed by Charlie Bi
# The struct PacBioInfo is to simplify wdl-input.json and use smrtcells' output to drive the workflows of sample.trial and cohort.cohort, 
# but this workflow is to skip running hifiasm (sample/trio-levels)

import "../sample/sample.trial.wdl"
import "../cohort/cohort.wdl"
import "../common/structs.wdl"

workflow famcohort_thin
{
  input {
    String cohort_name
    Array[PacBioInfo] data_info

    File regions_file
    IndexedData reference
    Boolean run_jellyfish = false

    File chr_lengths

    File ref_modimers

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
    String deepvariant_image
    String glnexus_image

    File tr_bed
    File tg_list
    File tg_bed
    File score_matrix
    LastIndexedData last_reference
  }

  Array[String] regions = read_lines(regions_file)

  scatter (sample in data_info) {
    String sample_names = sample.name
    scatter (movie in sample.movie) {
      IndexedData bam = {"name":"~{movie}","datafile":"~{sample.path}/~{movie}.hg38.bam", "indexfile":"~{sample.path}/~{movie}.hg38.bam.bai"}
    }
  }
  Array[Array[IndexedData]] person_bams = bam
  Array[String] person_sample_names =sample_names

  scatter (sample in data_info) {
    scatter (movie in sample.movie) {
      if (run_jellyfish) {
        String jellyfish = "~{sample.path}/jellyfish/~{movie}.count.jf"
	String modimers  = "~{sample.path}/jellyfish/~{movie}.modimers.tsv.gz"
      }
    }
  }
  Array[Array[File?]] person_jellyfish_input = jellyfish
  Array[Array[File?]] person_movie_modimers = modimers


  #call sample/sample.trial.wdl for all samples defined in this family
  call sample.trial.sample_family {
    input:
      person_sample_names      = person_sample_names,
      person_sample            = person_bams,
      person_jellyfish_input   = person_jellyfish_input,
      run_jellyfish = run_jellyfish,

      regions = regions,
      reference = reference,

      ref_modimers = ref_modimers,
      person_movie_modimers = person_movie_modimers,

      chr_lengths = chr_lengths,

      pb_conda_image = pb_conda_image,
      deepvariant_image = deepvariant_image,

      tr_bed = tr_bed,
      tg_list = tg_list,
      tg_bed = tg_bed,
      score_matrix = score_matrix,
      last_reference = last_reference
  }

  call cohort.cohort {
    input:
      cohort_name = cohort_name,
      regions = regions,
      reference = reference,

      person_deepvariant_phased_vcf_gz = sample_family.person_deepvariant_phased_vcf_gz,

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

      person_svsigs = sample_family.person_svsig_gv,

      person_bams = person_bams,
      person_gvcfs = sample_family.person_gvcf,

      pb_conda_image = pb_conda_image,
      glnexus_image = glnexus_image
  }
  output {
    Array[IndexedData] person_gvcf                        = sample_family.person_gvcf
    Array[Array[Array[File]]] person_svsig_gv             = sample_family.person_svsig_gv
    Array[IndexedData] person_deepvariant_phased_vcf_gz   = sample_family.person_deepvariant_phased_vcf_gz

    Array[File?] person_tandem_genotypes           = sample_family.person_tandem_genotypes
    Array[File?] person_tandem_genotypes_absolute  = sample_family.person_tandem_genotypes_absolute
    Array[File?] person_tandem_genotypes_plot      = sample_family.person_tandem_genotypes_plot
    Array[File?] person_tandem_genotypes_dropouts  = sample_family.person_tandem_genotypes_dropouts
  }
}
