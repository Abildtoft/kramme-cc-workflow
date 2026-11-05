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
        "trackbed/scripts/synced-contracts.yaml",
        "trackbed/skills/workflow:cleanup-artifacts/references/disposable-artifacts.yaml",
      ],
      options: { parser: "json" },
    },
  ],
};
