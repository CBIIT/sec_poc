## Inputs

### Disease code(s)

A set of NCIt disease codes to query on.

> Converting from NCIt disease names to codes can be accomplished programmatically by joining the [NCIt](https://evs.nci.nih.gov/ftp1/NCI_Thesaurus/) and the preferred name from the [EVS API](https://api-evsrest.nci.nih.gov/api/v1/concept/ncit?list=C4782&include=summary).

Call this input `disease_codes`.

## Outputs

### NCT Trial IDs

A set of NCT Trial IDs.

Each identified trial is coded in one of the following ways,

- It contains at least one of the `disease_codes` at the **TREE** level.
  > diseases.inclusion_indicator = "TREE". In this case, the trial contains a descendant disease of `disease_codes`.
- It contains at least one of the `disease_codes` at the **TRIAL** level.
  > diseases.inclusion_indicator = "TRIAL". In this case, the trial explicitly names `disease_codes` as part of the study.
- It contains an ancestor code of one of the `disease_codes` at the **TRIAL** level.

## Algorithm

1. Fetch all pages of trials from CTS API /v2/trials. The example below, in R, shows the essential body parameters.

   ```r
   body_params = list(
       diseases.nci_thesaurus_concept_id = disease_codes,
       include = c("nct_id", "diseases")
   )
   ```

2. Flatten the list of trials into a list of tabular-like (or dictionary-like) data containing the following columns/keys,

   | nct_id(str) | disease(str)                                    | code(str) | parents(str \| list) |
   | ----------- | ----------------------------------------------- | --------- | -------------------- |
   | NCT06270888 | Refractory Multiple Myeloma/Plasma Cell Myeloma | C7024     | C7813,C3242,C204126  |
   | ...         |

   Call this list `trial_diseases`.

3. Create an empty set called `visited_codes`.
4. For each trial's disease table,
   1. Check if the set of `disease_codes` is in the set `visited_codes`. If so, that means that all ancestor codes of `disease_codes` have been visited. Exit the loop.
   2. Lookup which `disease_codes` are in the trial's disease table. There should be at least one. Call this set `codes_in_trial`.
   3. Take the difference between `codes_in_trial` and `visited_codes`. Call this set `codes_to_visit`.
   4. If size of `codes_to_visit` is 0. Continue to next trial.
   5. Visit all ancestor codes of `codes_to_visit`.
      1. Initialize starting codes to `codes_to_visit`.
      2. If the starting codes are not contained in `visited_codes`, add them.
      3. Retrieve the parent codes of starting codes. The parents should be indexed in the trial's disease table.
      4. Set `codes_to_visit` to the parent codes.
      5. Repeat from step #1 until there are no more parent codes to visit.
5. Take the difference between `visited_codes` and `disease_codes`. Call this set `ancestor_codes`.
6. Fetch all pages of trials from CTS API /v2/trials. The example below, in R, shows the essential body parameters.

   ```r
   body_params = list(
       diseases.nci_thesaurus_concept_id = ancestor_codes,
       diseases.inclusion_indicator = "TRIAL"
   )
   ```

7. Combine the set of `trial_diseases$nct_id` with the set of NCT IDs from the previous step.
8. Return this complete set of NCT IDs.
