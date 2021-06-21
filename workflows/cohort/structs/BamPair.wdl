version 1.0

struct IndexedData {
  String? name
  File datafile
  File indexfile
}

struct SampleInput {
  Array[IndexedData] bam_pairs
  Array[File] jellyfish_input
}

struct TrialSampleInput {
  Array[SampleInput] affected_patient_inputs
  Array[SampleInput] unaffected_patient_inputs
}

struct SampleOutput {
    IndexedData gvcf
    Array[Array[File]] svsig_gv
    Array[IndexedData] bam_pairs
}

struct TrialSampleOutput {
  Array[SampleOutput] affected_patient_outputs
  Array[SampleOutput] unaffected_patient_outputs
}
