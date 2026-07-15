// @ts-check
"use strict";

const fs = require("fs");
const path = require("path");

/**
 * @typedef {{ type: string, required: boolean, loader_property?: string }} FrontmatterFieldContract
 * @typedef {{ fields: Record<string, FrontmatterFieldContract> }} FrontmatterContract
 * @typedef {{ required_fields: string[] }} SourceManifestContract
 * @typedef {{ skill_frontmatter: FrontmatterContract, source_manifest: SourceManifestContract }} SkillContracts
 */

/** @type {SkillContracts} */
const skillContracts = JSON.parse(
  fs.readFileSync(path.join(__dirname, "skill-contracts.json"), "utf8"),
);

function skillFrontmatterFields() {
  return skillContracts.skill_frontmatter?.fields ?? {};
}

/** @param {string} type */
function skillFrontmatterFieldNamesByType(type) {
  return Object.entries(skillFrontmatterFields())
    .filter(([, contract]) => contract?.type === type)
    .map(([field]) => field);
}

function skillFrontmatterRequiredFields() {
  return Object.entries(skillFrontmatterFields())
    .filter(([, contract]) => contract?.required === true)
    .map(([field]) => field);
}

/**
 * @param {string} loaderProperty
 * @param {string} fallback
 */
function skillFrontmatterFieldByLoaderProperty(loaderProperty, fallback) {
  const match = Object.entries(skillFrontmatterFields()).find(
    ([, contract]) => contract?.loader_property === loaderProperty,
  );
  return match ? match[0] : fallback;
}

const SKILL_FRONTMATTER_BOOLEAN_FIELDS = new Set(
  skillFrontmatterFieldNamesByType("boolean"),
);
const SKILL_FRONTMATTER_REQUIRED_FIELDS = skillFrontmatterRequiredFields();
const SOURCE_MANIFEST_REQUIRED_FIELDS =
  skillContracts.source_manifest?.required_fields ?? [];

module.exports = {
  SKILL_FRONTMATTER_BOOLEAN_FIELDS,
  SKILL_FRONTMATTER_REQUIRED_FIELDS,
  SOURCE_MANIFEST_REQUIRED_FIELDS,
  skillContracts,
  skillFrontmatterFieldByLoaderProperty,
  skillFrontmatterFieldNamesByType,
  skillFrontmatterRequiredFields,
};
