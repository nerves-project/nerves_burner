# .credo.exs
%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/"],
      },
      strict: true,
      checks: [
        {Credo.Check.Refactor.MapInto, false},
        {Credo.Check.Warning.LazyLogging, false},
        {Credo.Check.Readability.LargeNumbers, only_greater_than: 86400},
        {Credo.Check.Readability.ParenthesesOnZeroArityDefs, parens: true},
        {Credo.Check.Readability.Specs, tags: []},
        {Credo.Check.Readability.StrictModuleLayout, tags: []},
        {Credo.Check.Refactor.Nesting, max_nesting: 5},
        {Credo.Check.Refactor.CyclomaticComplexity, max_complexity: 15}
      ]
    }
  ]
}
