%{
  configs: [
    %{
      name: "default",
      files: %{
        included: ["lib/"],
      },
      checks: [
        {Credo.Check.Readability.MaxLineLength, priority: :low, max_length: 120}
      ]
    }
  ]
}