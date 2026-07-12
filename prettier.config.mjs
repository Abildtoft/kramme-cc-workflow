export default {
  endOfLine: "lf",
  plugins: [
    "@ianvs/prettier-plugin-sort-imports",
    "prettier-plugin-packagejson",
    "prettier-plugin-sh",
  ],
  proseWrap: "never",
  tabWidth: 2,
  useTabs: false,
  overrides: [
    {
      files: [
        "kramme-cc-workflow/scripts/synced-contracts.yaml",
        "kramme-cc-workflow/skills/kramme:workflow-artifacts:cleanup/references/disposable-artifacts.yaml",
      ],
      options: { parser: "json" },
    },
  ],
};
