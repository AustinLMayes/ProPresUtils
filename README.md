# ProPresUtils
Various Ruby scripts to assist with ProPresenter documents.

Depends on [RubyCommon](https://github.com/AustinLMayes/RubyCommon)

## Scripts
- `arrangement_extractor.rb` - Extract song arrangements from documents and save them to text files
- `arrangement_importer.rb` - Import song arrangements from text files back into documents - useful for re-importing documents from text without losing arrangement data
- `presentation_cleaner.rb` - Standardize PropPresenter presentations by:
    - Setting the corrent name/author information in CCLI metadata based on document file name
    - Applying cut transitions to non-empty slides
    - Removing all transitions from empty slides
    - Adding "Visual" and "Spacer" slides and placing them appropriately
    - Clearing the selected arrangement
- `text_extractor.rb` - Extract all text content from a document and save it to a text file that can be directly re-imported and result in the same base document
