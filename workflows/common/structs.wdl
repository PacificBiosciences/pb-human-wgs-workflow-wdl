version 1.0

struct IndexedData {
  String? name
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
  Array[SampleInfo] affected_persons
  Array[SampleInfo] unaffected_persons
}
