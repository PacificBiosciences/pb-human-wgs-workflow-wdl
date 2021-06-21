version 1.0

struct IndexedData {
  File datafile
  File indexfile
}

struct SmrtcellInfo {
  String name
  File path
  Boolean isUbam
}

struct SampleInfo {
  String name
  Array[SmrtcellInfo] smrtcells
}

struct CohortInfo {
  Array[SampleInfo] affected_patients
  Array[SampleInfo] unaffected_patients
}

struct SampleInput {
  Array[IndexedData] bam_pairs
  Array[File] jellyfish_input
}

struct TrialSampleInput {
  Array[SampleInput] affected_patient_inputs
  Array[SampleInput] unaffected_patient_inputs
}