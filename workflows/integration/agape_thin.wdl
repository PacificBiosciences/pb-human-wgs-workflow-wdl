version 1.0

#main workflow: agape_thin.wdl -- simplify the input-data for PacBio-samples

#import "../smrtcells/smrtcells.trial.wdl"
#import "../sample/sample.trial.wdl"
#import "../cohort/cohort.wdl"
#import "../common/structs.wdl"
#import "../hifiasm/sample_hifiasm.cohort.wdl"
#import "../hifiasm/trio_hifiasm.cohort.wdl"

import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/smrtcells/smrtcells.trial.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/sample/sample.trial.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/cohort/cohort.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/common/structs.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/hifiasm/trio_hifiasm.cohort.wdl"
import "https://raw.githubusercontent.com/cbi-star/pb-human-wgs-workflow-wdl/main/workflows/hifiasm/sample_hifiasm.cohort.wdl"

#THIS DATA STRUCTURE USED TO SIMPLIFY WDL-INPUT FOR PACBIO-SAMPLES
struct PacBioSampInfo {
  String name
  Array[String] parents
  Boolean? affected
  String path
  Array[String] movies
}

workflow agape {
  input {
    String cohort_name
    IndexedData reference

    File regions_file

    Array[PacBioSampInfo] pacbio_info
    Boolean ubam_bool
    String ubam_postfix
    Int kmer_length

    Array[String] parents_list

    File tr_bed
    File chr_lengths

    File hpoannotations
    File hpoterms
    File hpodag
    File gff
    File ensembl_to_hgnc
    File js
    File lof_lookup
    File gnomad_af
    File hprc_af
    File allyaml
    File ped
    File clinvar_lookup

    String pb_conda_image
    String deepvariant_image
    String glnexus_image

    File ref_modimers
    
    Boolean run_jellyfish = false   #default is to NOT run jellyfish
    Boolean trioeval = false        #default is to NOT run trioeval
    Boolean triobin = true          #default is to run triobin

    File tg_list
    File tg_bed
    File score_matrix
    LastIndexedData last_reference

  }

  Array[String] regions = read_lines(regions_file)

  scatter (samp in pacbio_info) {
    scatter (movie in samp.movies) {
      SmrtcellInfo smrtcell = { "name": "~{movie}", "path": "~{samp.path}/~{movie}.~{ubam_postfix}" }
    }
  }
  Array[Array[SmrtcellInfo]] smrtcells = smrtcell

  Int num_samples = length(pacbio_info)
  scatter (n in range(num_samples)) {
    SampleInfo sample_info = { "name": "~{pacbio_info[n].name}", "parents": pacbio_info[n].parents, "smrtcells": smrtcells[n] }
  }
  Array[SampleInfo] cohort_info = sample_info

  #call smrtcells/smrtcells.trial.wdl
  call smrtcells.trial.smrtcells_cohort {
    input:
      reference = reference,
      cohort_info = cohort_info,
      kmer_length = kmer_length,

      pb_conda_image = pb_conda_image,
      run_jellyfish = run_jellyfish
  }


  #run sample-level hifiasm -- call hifiasm/sample_hifiasm.cohort.wdl for all samples
  call sample_hifiasm.cohort.sample_hifiasm_cohort {
     input:
       fasta_info = smrtcells_cohort.fasta_info,
       reference = reference,
       pb_conda_image = pb_conda_image
  }

  #call sample/sample.trial.wdl for all samples defined in this family
  call sample.trial.sample_family {
    input:
      person_sample_names      = smrtcells_cohort.person_sample_names,
      person_sample            = smrtcells_cohort.person_bams,
      person_jellyfish_input   = smrtcells_cohort.person_jellyfish_count,

      regions = regions,
      reference = reference,

      ref_modimers = ref_modimers,
      person_movie_modimers = smrtcells_cohort.person_movie_modimers,

      tr_bed = tr_bed,
      chr_lengths = chr_lengths,

      pb_conda_image = pb_conda_image,
      deepvariant_image = deepvariant_image,

      run_jellyfish = run_jellyfish,

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

      person_bams = smrtcells_cohort.person_bams,
      person_gvcfs = sample_family.person_gvcf,

      pb_conda_image = pb_conda_image,
      glnexus_image = glnexus_image
  }
 
  
  Int num_parents_list = length(parents_list)
  Boolean trio_yak = if num_parents_list == 2 then true else false

  #Run trio-level hifiasm -- call hifiasm/trio_hifiasm.cohort.wdl only if both parents exist
  if (trio_yak){
    call trio_hifiasm.cohort.trio_hifiasm_cohort {
      input:
       fasta_info = smrtcells_cohort.fasta_info,
       person_parents_names = smrtcells_cohort.person_parents_names,
       parents_list = parents_list,
       pb_conda_image = pb_conda_image,
       reference = reference,
       trioeval = trioeval,
       triobin = triobin
    }
  }
  
  output {
    Array[Array[IndexedData]] person_bams        = smrtcells_cohort.person_bams
    Array[Array[File?]] person_jellyfish_count    = smrtcells_cohort.person_jellyfish_count

    Array[IndexedData] person_gvcf                        = sample_family.person_gvcf
    Array[Array[Array[File]]] person_svsig_gv             = sample_family.person_svsig_gv
    Array[IndexedData] person_deepvariant_phased_vcf_gz   = sample_family.person_deepvariant_phased_vcf_gz

    Array[File?] person_tandem_genotypes           = sample_family.person_tandem_genotypes
    Array[File?] person_tandem_genotypes_absolute  = sample_family.person_tandem_genotypes_absolute
    Array[File?] person_tandem_genotypes_plot      = sample_family.person_tandem_genotypes_plot
    Array[File?] person_tandem_genotypes_dropouts  = sample_family.person_tandem_genotypes_dropouts

  }
}
