/*****************************************************************************
 * Project: RooFit                                                           *
 * Package: RooFitCore                                                       *
 *    File: $Id: RooAbsCategory.h,v 1.38 2007/05/11 09:11:30 verkerke Exp $
 * Authors:                                                                  *
 *   WV, Wouter Verkerke, UC Santa Barbara, verkerke@slac.stanford.edu       *
 *   DK, David Kirkby,    UC Irvine,         dkirkby@uci.edu                 *
 *                                                                           *
 * Copyright (c) 2000-2005, Regents of the University of California          *
 *                          and Stanford University. All rights reserved.    *
 *                                                                           *
 * Redistribution and use in source and binary forms,                        *
 * with or without modification, are permitted according to the terms        *
 * listed in LICENSE (http://roofit.sourceforge.net/license.txt)             *
 *****************************************************************************/
#ifndef ROO_ABS_CATEGORY
#define ROO_ABS_CATEGORY

#include "RooAbsArg.h"

#include <string>
#include <map>
#include <functional>
#include <vector>

#ifdef R__LESS_INCLUDES
class RooCatType;
#else
#include "RooCatType.h"
#endif

class TTree;
class RooVectorDataStore;
class Roo1DTable;
class TIterator;
struct TreeReadBuffer; /// A space to attach TBranches

class RooAbsCategory : public RooAbsArg {
public:
  /// The type used to denote a specific category state.
  using value_type = int;

  // Constructors, assignment etc.
  RooAbsCategory();
  RooAbsCategory(const char *name, const char *title);
  RooAbsCategory(const RooAbsCategory& other, const char* name=0) ;
  ~RooAbsCategory() override;

  // Value accessors
  virtual value_type getCurrentIndex() const ;
  virtual const char* getCurrentLabel() const ;

  const std::map<std::string, value_type>::value_type& getOrdinal(unsigned int n) const;
  unsigned int getCurrentOrdinalNumber() const;

  bool operator==(value_type index) const ;
  bool operator!=(value_type index) {  return !operator==(index);}
  bool operator==(const char* label) const ;
  bool operator!=(const char* label) { return !operator==(label);}
  bool operator==(const RooAbsArg& other) const override ;
  bool         operator!=(const RooAbsArg& other) { return !operator==(other);}
  bool isIdentical(const RooAbsArg& other, bool assumeSameType=false) const override;

  /// Check if a state with name `label` exists.
  bool hasLabel(const std::string& label) const {
    return stateNames().find(label) != stateNames().end();
  }
  /// Check if a state with index `index` exists.
  bool hasIndex(value_type index) const;

  /// Get the name corresponding to the given index.
  /// \return Name or empty string if index is invalid.
  const std::string& lookupName(value_type index) const;
  value_type lookupIndex(const std::string& stateName) const;


  bool isSignType(bool mustHaveZero=false) const ;

  Roo1DTable *createTable(const char *label) const ;

  // I/O streaming interface
  bool readFromStream(std::istream& is, bool compact, bool verbose=false) override ;
  void writeToStream(std::ostream& os, bool compact) const override ;

  void printValue(std::ostream& os) const override ;
  void printMultiline(std::ostream& os, Int_t contents, bool verbose=false, TString indent="") const override ;

  virtual bool isIntegrationSafeLValue(const RooArgSet* /*set*/) const {
    // Is this l-value object safe for use as integration observable
    return true ;
  }

  RooAbsArg *createFundamental(const char* newname=0) const override;

  /// Iterator for category state names. Points to pairs of index and name.
  std::map<std::string, value_type>::const_iterator begin() const {
    return stateNames().cbegin();
  }
  /// Iterator for category state names. Points to pairs of index and name.
  std::map<std::string, value_type>::const_iterator end() const {
    return stateNames().cend();
  }
  /// Number of states defined.
  std::size_t size() const {
    return stateNames().size();
  }
  /// If there are no states defined
  bool empty() const {
    return stateNames().empty();
  }

  bool isCategory() const override { return true; }

  /// \name Legacy interface
  /// Previous versions of RooAbsCategory were based on RooCatType, a class containing a state and a label.
  /// It has been replaced by integers, which use less space and allow for faster access. The following part of the interface
  /// should not be used if possible.
  /// Since RooCatType in essence is only an index and a state name, equivalent functionality can be achieved using begin()
  /// and end() to iterate through pairs of <index, stateName> and by using using lookupName() and lookupIndex().
  /// @{
  const RooCatType*
  R__SUGGEST_ALTERNATIVE("This interface is inefficient. Use lookupName()")
  lookupType(value_type index, bool printError=false) const;
  const RooCatType*
  R__SUGGEST_ALTERNATIVE("This interface is inefficient. Use lookupIndex()")
  lookupType(const char* label, bool printError=false) const;
  const RooCatType*
  R__SUGGEST_ALTERNATIVE("This interface is inefficient. Use lookupName() / lookupIndex()")
  lookupType(const RooCatType& type, bool printError=false) const;
  TIterator*
  R__SUGGEST_ALTERNATIVE("This interface is inefficient. Use begin(), end() or range-based for loops.")
  typeIterator() const;
  /// Return number of types defined (in range named rangeName if rangeName!=0)
  Int_t numTypes(const char* /*rangeName*/=0) const {
    return stateNames().size();
  }
  /// Retrieve the current index. Use getCurrentIndex() for more clarity.
  Int_t getIndex() const { return getCurrentIndex(); }
  /// Retrieve current label. Use getCurrentLabel() for more clarity.
  const char* getLabel() const { return getCurrentLabel(); }
protected:
  virtual bool
  R__SUGGEST_ALTERNATIVE("This interface is inefficient. Use hasIndex() or hasLabel().")
  isValid(const RooCatType& value) const ;
  /// \deprecated Use defineState(const std::string& label)
  const RooCatType*
  R__SUGGEST_ALTERNATIVE("This interface is inefficient. Use defineState().")
  defineType(const char* label);
  /// \deprecated Use defineState(const std::string& label, value_type index)
  const RooCatType*
  R__SUGGEST_ALTERNATIVE("This interface is inefficient. Use defineState().")
  defineType(const char* label, int index);
  /// \deprecated Use defineStateUnchecked(const std::string& label, value_type index)
  const RooCatType*
  R__SUGGEST_ALTERNATIVE("This interface is inefficient. Use defineTypeUnchecked().")
  defineTypeUnchecked(const char* label, value_type index);
  /// @}


protected:
  /// Access the map of state names to index numbers. Triggers a recomputation
  /// if the shape is dirty.
  const std::map<std::string, value_type>& stateNames() const {
    if (isShapeDirty()) {
      _legacyStates.clear();
      const_cast<RooAbsCategory*>(this)->recomputeShape();
      clearShapeDirty();
    }

    return _stateNames;
  }
  /// \copydoc stateNames() const
  std::map<std::string, value_type>& stateNames() {
    if (isShapeDirty()) {
      _legacyStates.clear();
      recomputeShape();
      clearShapeDirty();
    }

    //Somebody might modify the states
    setShapeDirty();

    return _stateNames;
  }

  /// Evaluate the category state and return.
  /// The returned state index should correspond to a state name that has been defined via e.g. defineType().
  virtual value_type evaluate() const = 0;

  // Type definition management
  virtual const std::map<std::string, RooAbsCategory::value_type>::value_type& defineState(const std::string& label);
  virtual const std::map<std::string, RooAbsCategory::value_type>::value_type& defineState(const std::string& label, value_type index);

  void defineStateUnchecked(const std::string& label, value_type index);
  void clearTypes() ;

  bool isValid() const override {
    return hasIndex(_currentIndex);
  }

  /// If a category depends on the shape of others, i.e.\ its state numbers or names depend
  /// on the states of other categories, this function has to be implemented to recompute
  /// _stateNames and _insertionOrder.
  /// If one of these two changes, setShapeDirty() has to be called to propagate this information
  /// to possible users of this category.
  virtual void recomputeShape() = 0;

  friend class RooVectorDataStore ;
  void syncCache(const RooArgSet* set=0) override ;
  void copyCache(const RooAbsArg* source, bool valueOnly=false, bool setValueDirty=true) override ;
  void setCachedValue(double value, bool notifyClients = true) final;
  void attachToTree(TTree& t, Int_t bufSize=32000) override ;
  void attachToVStore(RooVectorDataStore& vstore) override ;
  void setTreeBranchStatus(TTree& t, bool active) override ;
  void fillTreeBranch(TTree& t) override ;

  RooCatType* retrieveLegacyState(value_type index) const;
  value_type nextAvailableStateIndex() const;


  mutable value_type _currentIndex{std::numeric_limits<int>::min()}; ///< Current category state
  std::map<std::string, value_type> _stateNames;                     ///< Map state names to index numbers. Make sure state names are updated in recomputeShape().
  std::vector<std::string> _insertionOrder;                          ///< Keeps track in which order state numbers have been inserted. Make sure this is updated in recomputeShape().
  mutable std::map<value_type, std::unique_ptr<RooCatType, std::function<void(RooCatType*)>> > _legacyStates; ///<! Map holding pointers to RooCatType instances. Only for legacy interface. Don't use if possible.

  static const decltype(_stateNames)::value_type& invalidCategory();

private:
  std::unique_ptr<TreeReadBuffer> _treeReadBuffer; //! A buffer for reading values from trees

  ClassDefOverride(RooAbsCategory, 4) // Abstract discrete variable
};

#endif
