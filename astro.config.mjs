import starlight from "@astrojs/starlight";
import { defineConfig } from "astro/config";

import vercel from "@astrojs/vercel";

import mdx from "@astrojs/mdx";

// https://astro.build/config
export default defineConfig({
  output: "server",
  integrations: [
    starlight({
      prerender: true,
      favicon: "favicon.ico",
      title: "suchcodewow",
      customCss: ["./src/styles.css"],
      components: {
        Sidebar: "./src/components/Sidebar.astro",
      },
      logo: {
        src: "/src/img/wow.png",
      },
      tableOfContents: {
        minHeadingLevel: 2,
        maxHeadingLevel: 4,
      },
      social: {
        github: "https://github.com/suchcodewow/scwastro",
      },
      sidebar: [
        {
          label: "Pepper",
          autogenerate: {
            directory: "pepper",
          },
        },
        {
          label: "HarnessEvents",
          autogenerate: {
            directory: "harnessevents",
          },
        },
        {
          label: "Scripts",
          autogenerate: {
            directory: "scripts",
          },
        },
        {
          label: "Accelerators",
          autogenerate: {
            directory: "accelerators",
          },
        },
        {
          label: "Harness",
          autogenerate: {
            directory: "harness",
          },
        },
        {
          label: "Full Stack Front-to-Back",
          autogenerate: {
            directory: "fronttoback",
          },
        },
        {
          label: "Harness: Globalcorp",
          autogenerate: {
            directory: "globalcorp",
          },
        },
        {
          label: "Test",
          autogenerate: {
            directory: "reference",
          },
        },
      ],
    }),
    mdx(),
  ],
  adapter: vercel(),
});
