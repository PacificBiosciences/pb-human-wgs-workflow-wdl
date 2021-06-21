version 1.0

import "./sample.wdl"

workflow sample_trial {
  input {
    String md5sum_name

    TrialSampleInput sample_trial_inputs
    Array[String] regions
    File tr_bed
    File reference
    File reference_index

    File chr_lengths
    File ref_modimers
    File movie_modimers

    String pb_conda_image
    String deepvariant_image
    String picard_image
  }

  scatter (sample_input in sample_trial_inputs.affected_patient_inputs) {
    call sample.sample as sample_affected_patient {
      input:
        md5sum_name = md5sum_name,
        regions = regions,
        bam_pairs = sample_input.bam_pairs,
        tr_bed = tr_bed,
        reference = reference,
        reference_index = reference_index,

        chr_lengths = chr_lengths,
        jellyfish_input = sample_input.jellyfish_input, 
        ref_modimers = ref_modimers,
        movie_modimers = movie_modimers,

        pb_conda_image = pb_conda_image,
        deepvariant_image = deepvariant_image,
        picard_image = picard_image
    }
  }

  scatter (sample_input in sample_trial_inputs.unaffected_patient_inputs) {
    call sample.sample as sample_unaffected_patient {
      input:
        md5sum_name = md5sum_name,
        regions = regions,
        bam_pairs = sample_input.bam_pairs,
        tr_bed = tr_bed,
        reference = reference,
        reference_index = reference_index,

        chr_lengths = chr_lengths,
        jellyfish_input = sample_input.jellyfish_input, 
        ref_modimers = ref_modimers,
        movie_modimers = movie_modimers,

        pb_conda_image = pb_conda_image,
        deepvariant_image = deepvariant_image,
        picard_image = picard_image
    }
  }

  output {
    Array[IndexedData] affected_patient_gvcf              = sample_affected_patient.gvcf
    Array[Array[Array[File]]] affected_patient_svsig_gv   = sample_affected_patient.svsig_gv
    Array[Array[IndexedData]] affected_patient_bams       = sample_affected_patient.bams

    Array[IndexedData] unaffected_patient_gvcf            = sample_unaffected_patient.gvcf
    Array[Array[Array[File]]] unaffected_patient_svsig_gv = sample_unaffected_patient.svsig_gv
    Array[Array[IndexedData]] unaffected_patient_bams     = sample_unaffected_patient.bams
  }
}
