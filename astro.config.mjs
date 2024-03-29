import { defineConfig } from "astro/config";
import starlight from "@astrojs/starlight";

// https://astro.build/config
export default defineConfig({
  integrations: [
    starlight({
      favicon: "favicon.ico",
      title: "SuchCodeWow",
      components: {
        Sidebar: "./src/components/Sidebar.astro",
      },
      logo: {
        src: "./src/assets/wow.png",
      },
      tableOfContents: { minHeadingLevel: 2, maxHeadingLevel: 3 },
      social: {
        github: "https://github.com/suchcodewow/scwastro",
      },
      sidebar: [
        {
          label: "Full Stack Front-to-Back",
          autogenerate: { directory: "fullstack" },
        },
        {
          label: "Pepper",
          autogenerate: { directory: "pepper" },
        },
        {
          label: "Scripts",
          autogenerate: { directory: "scripts" },
        },
      ],
    }),
  ],
});
